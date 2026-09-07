from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase

from tasks_demo.tasks import add, database_probe, uppercase


class DemoTaskTests(SimpleTestCase):
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
