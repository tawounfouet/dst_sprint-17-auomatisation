from unittest.mock import MagicMock, patch

from django.test import TestCase

from tasks_demo.tasks import (
    add,
    check_incoming_emails_imap,
    database_probe,
    periodic_heartbeat,
    process_media_file,
    send_email_async,
    uppercase,
)


class DemoTaskTests(TestCase):
    def test_add_task(self):
        self.assertEqual(add.run(21, 21), 42)

    def test_uppercase_task(self):
        self.assertEqual(uppercase.run("datascientest"), "DATASCIENTEST")

    @patch("tasks_demo.tasks.connection.cursor")
    def test_database_probe_task(self, cursor):
        context_manager = MagicMock()
        db_cursor = MagicMock()
        db_cursor.fetchone.return_value = (1,)
        context_manager.__enter__.return_value = db_cursor
        cursor.return_value = context_manager

        result = database_probe.run()

        self.assertEqual(result, {"database": "connected", "query": 1})
        db_cursor.execute.assert_called_once_with("SELECT 1")

    def test_periodic_heartbeat_task(self):
        result = periodic_heartbeat.run()
        self.assertEqual(result["status"], "heartbeat")
        self.assertIn("timestamp", result)

    def test_process_media_file_task(self):
        from django.core.files.base import ContentFile
        from django.core.files.storage import default_storage

        test_path = default_storage.save(
            "test_sample.txt",
            ContentFile(b"Line one\nLine two with five words\n"),
        )
        try:
            result = process_media_file.run(test_path)
            self.assertEqual(result["status"], "success")
            self.assertEqual(result["original_file"], test_path)
            self.assertEqual(result["line_count"], 2)
            self.assertEqual(result["word_count"], 7)
            self.assertTrue(default_storage.exists(result["report_file"]))
            # Clean up report
            default_storage.delete(result["report_file"])
        finally:
            default_storage.delete(test_path)

    def test_process_media_file_missing(self):
        result = process_media_file.run("non_existent_file_xyz.txt")
        self.assertEqual(result["status"], "error")
        self.assertIn("File not found", result["error"])

    @patch("django.core.mail.EmailMessage.send")
    def test_send_email_async_success(self, mock_send):
        mock_send.return_value = 1
        result = send_email_async.run(
            to_email="recipient@example.com",
            subject="Welcome!",
            message="Thank you for testing Antigravity Email.",
        )
        self.assertEqual(result["status"], "sent")
        self.assertEqual(result["to"], ["recipient@example.com"])
        self.assertEqual(result["sent_count"], 1)
        mock_send.assert_called_once()

    @patch("django.core.mail.EmailMessage.send")
    def test_send_email_async_with_attachment(self, mock_send):
        from django.core.files.base import ContentFile
        from django.core.files.storage import default_storage

        mock_send.return_value = 1
        att_path = default_storage.save("test_email_attachment.txt", ContentFile(b"Invoice PDF mock"))
        try:
            result = send_email_async.run(
                to_email="client@example.com",
                subject="Invoice",
                message="Please find attached.",
                attachment_paths=[att_path],
            )
            self.assertEqual(result["status"], "sent")
            mock_send.assert_called_once()
        finally:
            default_storage.delete(att_path)

    def test_check_incoming_emails_imap_skipped_when_unconfigured(self):
        with patch("django.conf.settings.IMAP_HOST", ""):
            result = check_incoming_emails_imap.run()
            self.assertEqual(result["status"], "skipped")
            self.assertEqual(result["reason"], "imap_unconfigured")

    @patch("imaplib.IMAP4_SSL")
    def test_check_incoming_emails_imap_mocked(self, mock_imap_class):
        mock_client = MagicMock()
        mock_client.search.return_value = ("OK", [b""])
        mock_imap_class.return_value = mock_client

        with patch("django.conf.settings.IMAP_HOST", "imap.mock.example.com"), \
             patch("django.conf.settings.IMAP_USER", "test@mock.example.com"), \
             patch("django.conf.settings.IMAP_PASSWORD", "secret"), \
             patch("django.conf.settings.IMAP_USE_SSL", True):
            result = check_incoming_emails_imap.run()
            self.assertEqual(result["status"], "success")
            self.assertEqual(result["processed_count"], 0)
            mock_client.login.assert_called_once_with("test@mock.example.com", "secret")
            mock_client.select.assert_called_once_with("INBOX")
