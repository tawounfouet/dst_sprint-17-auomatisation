from unittest.mock import MagicMock, patch

from django.test import TestCase


class HealthEndpointTests(TestCase):
    def test_home(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["application"], "dst-ansible-django")

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

    @patch("health.views.redis_client.from_url")
    def test_redis_health_success(self, redis_from_url):
        client = MagicMock()
        client.ping.return_value = True
        redis_from_url.return_value = client

        response = self.client.get("/health/redis/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"status": "healthy", "redis": "connected"},
        )
        client.ping.assert_called_once_with()
        client.close.assert_called_once_with()

    @patch("health.views.redis_client.from_url", side_effect=RuntimeError("redis unavailable"))
    def test_redis_health_failure(self, _redis_from_url):
        response = self.client.get("/health/redis/")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json(),
            {"status": "unhealthy", "redis": "disconnected"},
        )

    @patch("health.views.celery_app.control.ping")
    def test_celery_health_success(self, celery_ping):
        celery_ping.return_value = [{"worker1@example": {"ok": "pong"}}]

        response = self.client.get("/health/celery/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"status": "healthy", "celery": "connected", "workers": 1},
        )

    @patch("health.views.celery_app.control.ping", return_value=[])
    def test_celery_health_failure(self, _celery_ping):
        response = self.client.get("/health/celery/")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json(),
            {"status": "unhealthy", "celery": "unavailable", "workers": 0},
        )

    def test_info(self):
        response = self.client.get("/api/info/")
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["application"], "dst-ansible-django")
        self.assertEqual(payload["database"], "postgresql")
        self.assertEqual(payload["broker"], "redis")
        self.assertEqual(payload["async_runtime"], "celery")
        self.assertEqual(payload["scheduler"], "django-celery-beat")

    def test_custom_application_name_override(self):
        with self.settings(APPLICATION_NAME="mon-app-custom"):
            response = self.client.get("/")
            self.assertEqual(response.json()["application"], "mon-app-custom")
            response_info = self.client.get("/api/info/")
            self.assertEqual(response_info.json()["application"], "mon-app-custom")
