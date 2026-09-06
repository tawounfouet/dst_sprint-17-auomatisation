from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase


class HealthEndpointTests(SimpleTestCase):
    def test_home(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["application"], "datascientest-ansible-django")

    def test_health(self):
        response = self.client.get("/health/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "healthy"})

    @patch("health.views.connection.cursor")
    def test_database_health_success(self, cursor):
        context_manager = MagicMock()
        db_cursor = MagicMock()
        db_cursor.fetchone.return_value = (1,)
        context_manager.__enter__.return_value = db_cursor
        cursor.return_value = context_manager

        response = self.client.get("/health/database/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"status": "healthy", "database": "connected", "query": 1},
        )
        db_cursor.execute.assert_called_once_with("SELECT 1")

    @patch("health.views.connection.cursor", side_effect=RuntimeError("db unavailable"))
    def test_database_health_failure(self, _cursor):
        response = self.client.get("/health/database/")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json(),
            {"status": "unhealthy", "database": "disconnected"},
        )

    def test_info(self):
        response = self.client.get("/api/info/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["database"], "postgresql")
