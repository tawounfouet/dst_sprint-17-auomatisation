from unittest.mock import MagicMock, patch

from django.test import TestCase

from tasks_demo.tasks import (
    add,
    database_probe,
    periodic_heartbeat,
    process_media_file,
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
