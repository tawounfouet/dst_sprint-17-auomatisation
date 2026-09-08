from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase
from rest_framework.test import APIClient


class TaskApiTests(SimpleTestCase):
    def setUp(self):
        self.client = APIClient()

    @patch("tasks_demo.views.add.delay")
    def test_submit_add(self, delay):
        delay.return_value = MagicMock(id="task-add-1", status="PENDING")

        response = self.client.post(
            "/api/tasks/add/",
            {"x": 21, "y": 21},
            format="json",
        )

        self.assertEqual(response.status_code, 202)
        self.assertEqual(
            response.json(),
            {"task_id": "task-add-1", "status": "PENDING"},
        )
        delay.assert_called_once_with(21, 21)

    def test_submit_add_rejects_string_number(self):
        response = self.client.post(
            "/api/tasks/add/",
            {"x": "21", "y": 21},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"error": "x_and_y_must_be_numbers"})

    def test_submit_add_rejects_boolean(self):
        response = self.client.post(
            "/api/tasks/add/",
            {"x": True, "y": 21},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"error": "x_and_y_must_be_numbers"})

    def test_submit_add_rejects_missing_field(self):
        response = self.client.post(
            "/api/tasks/add/",
            {"x": 21},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"error": "x_and_y_must_be_numbers"})

    def test_submit_add_rejects_invalid_json_with_legacy_error_contract(self):
        response = self.client.post(
            "/api/tasks/add/",
            data='{"x": 21,',
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"error": "invalid_json"})

    @patch("tasks_demo.views.uppercase.delay")
    def test_submit_uppercase(self, delay):
        delay.return_value = MagicMock(id="task-uppercase-1", status="PENDING")

        response = self.client.post(
            "/api/tasks/uppercase/",
            {"value": "datascientest"},
            format="json",
        )

        self.assertEqual(response.status_code, 202)
        self.assertEqual(response.json()["task_id"], "task-uppercase-1")
        delay.assert_called_once_with("datascientest")

    def test_submit_uppercase_rejects_empty_value(self):
        response = self.client.post(
            "/api/tasks/uppercase/",
            {"value": ""},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.json(),
            {"error": "value_must_be_a_non_empty_string_up_to_1024_chars"},
        )

    def test_submit_uppercase_rejects_too_long_value(self):
        response = self.client.post(
            "/api/tasks/uppercase/",
            {"value": "x" * 1025},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.json(),
            {"error": "value_must_be_a_non_empty_string_up_to_1024_chars"},
        )

    @patch("tasks_demo.views.database_probe.delay")
    def test_submit_database_probe(self, delay):
        delay.return_value = MagicMock(id="task-db-1", status="PENDING")

        response = self.client.post(
            "/api/tasks/database-probe/",
            {},
            format="json",
        )

        self.assertEqual(response.status_code, 202)
        self.assertEqual(response.json()["task_id"], "task-db-1")
        delay.assert_called_once_with()

    @patch("tasks_demo.views.AsyncResult")
    def test_task_status_success(self, async_result):
        result = MagicMock()
        result.status = "SUCCESS"
        result.successful.return_value = True
        result.failed.return_value = False
        result.result = 42
        async_result.return_value = result

        response = self.client.get("/api/tasks/task-add-1/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"task_id": "task-add-1", "status": "SUCCESS", "result": 42},
        )
        async_result.assert_called_once_with("task-add-1")

    @patch("tasks_demo.views.AsyncResult")
    def test_task_status_failure_does_not_leak_exception(self, async_result):
        result = MagicMock()
        result.status = "FAILURE"
        result.successful.return_value = False
        result.failed.return_value = True
        result.result = RuntimeError("sensitive backend detail")
        async_result.return_value = result

        response = self.client.get("/api/tasks/task-failed-1/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "task_id": "task-failed-1",
                "status": "FAILURE",
                "error": "task_failed",
            },
        )

    def test_post_endpoint_rejects_get(self):
        response = self.client.get("/api/tasks/add/")
        self.assertEqual(response.status_code, 405)

    @patch("tasks_demo.views.process_media_file.delay")
    def test_submit_media_upload_success(self, delay):
        from django.core.files.uploadedfile import SimpleUploadedFile

        delay.return_value = MagicMock(id="task-media-1", status="PENDING")
        uploaded_file = SimpleUploadedFile("sample.txt", b"Hello Antigravity MinIO!")

        response = self.client.post(
            "/api/tasks/media-upload/",
            {"file": uploaded_file},
            format="multipart",
        )

        self.assertEqual(response.status_code, 202)
        self.assertEqual(
            response.json(),
            {"task_id": "task-media-1", "status": "PENDING"},
        )
        delay.assert_called_once()
        args, _ = delay.call_args
        self.assertTrue(args[0].startswith("uploads/sample"))
        from django.core.files.storage import default_storage
        default_storage.delete(args[0])

    def test_submit_media_upload_requires_file(self):
        response = self.client.post(
            "/api/tasks/media-upload/",
            {},
            format="multipart",
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json(), {"error": "file_required"})
