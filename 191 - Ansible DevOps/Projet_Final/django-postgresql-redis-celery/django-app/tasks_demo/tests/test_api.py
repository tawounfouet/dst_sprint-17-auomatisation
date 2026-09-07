import json
from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase


class TaskApiTests(SimpleTestCase):
    @patch("tasks_demo.views.add.delay")
    def test_submit_add(self, delay):
        delay.return_value = MagicMock(id="task-add-1", status="PENDING")

        response = self.client.post(
            "/api/tasks/add/",
            data=json.dumps({"x": 21, "y": 21}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 202)
        self.assertEqual(response.json(), {"task_id": "task-add-1", "status": "PENDING"})
        delay.assert_called_once_with(21, 21)

    def test_submit_add_rejects_invalid_payload(self):
        response = self.client.post(
            "/api/tasks/add/",
            data=json.dumps({"x": "21", "y": 21}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["error"], "x_and_y_must_be_numbers")

    @patch("tasks_demo.views.uppercase.delay")
    def test_submit_uppercase(self, delay):
        delay.return_value = MagicMock(id="task-uppercase-1", status="PENDING")

        response = self.client.post(
            "/api/tasks/uppercase/",
            data=json.dumps({"value": "datascientest"}),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 202)
        self.assertEqual(response.json()["task_id"], "task-uppercase-1")
        delay.assert_called_once_with("datascientest")

    @patch("tasks_demo.views.database_probe.delay")
    def test_submit_database_probe(self, delay):
        delay.return_value = MagicMock(id="task-db-1", status="PENDING")

        response = self.client.post(
            "/api/tasks/database-probe/",
            data="{}",
            content_type="application/json",
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
            {"task_id": "task-failed-1", "status": "FAILURE", "error": "task_failed"},
        )
