import os
import subprocess
import sys
import unittest
from pathlib import Path


DJANGO_ROOT = Path(__file__).resolve().parents[1]


class SettingsRuntimePolicyTests(unittest.TestCase):
    def _run_import(self, settings_module, application_env, **overrides):
        env = os.environ.copy()
        for key in (
            "APPLICATION_NAME",
            "APPLICATION_ENV",
            "DJANGO_SETTINGS_MODULE",
            "DJANGO_SECRET_KEY",
            "DJANGO_DEBUG",
            "DATABASE_URL",
            "CELERY_BROKER_URL",
            "CELERY_RESULT_BACKEND",
            "USE_S3_STORAGE",
            "AWS_STORAGE_BUCKET_NAME",
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY",
            "AWS_S3_ENDPOINT_URL",
            "SMTP_HOST",
            "SMTP_USER",
            "SMTP_PASSWORD",
        ):
            env.pop(key, None)

        env.update(
            {
                "APPLICATION_ENV": application_env,
                "DJANGO_SETTINGS_MODULE": settings_module,
                "DJANGO_SECRET_KEY": (
                    "STATIC_CHECK_ONLY_DJANGO_SECRET_KEY_"
                    "0123456789abcdefghijklmnopqrstuvwxyzABCDEFG"
                ),
                "DJANGO_DEBUG": "false",
                "CELERY_BROKER_URL": "redis://:canary@redis:6379/0",
                "CELERY_RESULT_BACKEND": "redis://:canary@redis:6379/1",
                "AWS_STORAGE_BUCKET_NAME": "canary-bucket",
                "AWS_ACCESS_KEY_ID": "canary-access-key",
                "AWS_SECRET_ACCESS_KEY": "canary-secret-key",
                "SMTP_HOST": "smtp.canary.example.com",
                "SMTP_USER": "canary_user",
                "SMTP_PASSWORD": "canary_password",
            }
        )
        env.update(overrides)

        code = (
            "import importlib; "
            f"s=importlib.import_module('{settings_module}'); "
            "print(s.APPLICATION_ENV); "
            "print(s.DATABASES['default']['ENGINE']); "
            "print(s.DEBUG)"
        )
        return subprocess.run(
            [sys.executable, "-c", code],
            cwd=DJANGO_ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_dev_without_database_url_uses_sqlite(self):
        result = self._run_import("config.settings.dev", "dev")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("django.db.backends.sqlite3", result.stdout)

    def test_environment_must_match_settings_module(self):
        result = self._run_import(
            "config.settings.prod",
            "dev",
            DATABASE_URL="postgresql://django_app:canary@db:5432/django_app",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("APPLICATION_ENV must match DJANGO_SETTINGS_MODULE", result.stderr)

    def test_staging_without_database_url_fails(self):
        result = self._run_import("config.settings.stg", "stg")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DATABASE_URL is mandatory", result.stderr)

    def test_staging_rejects_sqlite(self):
        result = self._run_import(
            "config.settings.stg",
            "stg",
            DATABASE_URL="sqlite:///forbidden.sqlite3",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DATABASE_URL must use PostgreSQL", result.stderr)

    def test_production_rejects_sqlite(self):
        result = self._run_import(
            "config.settings.prod",
            "prod",
            DATABASE_URL="sqlite:///forbidden.sqlite3",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DATABASE_URL must use PostgreSQL", result.stderr)

    def test_production_rejects_short_secret_key(self):
        result = self._run_import(
            "config.settings.prod",
            "prod",
            DJANGO_SECRET_KEY="too-short",
            DATABASE_URL="postgresql://django_app:canary@db:5432/django_app",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DJANGO_SECRET_KEY", result.stderr)

    def test_production_requires_redis_celery_urls(self):
        result = self._run_import(
            "config.settings.prod",
            "prod",
            DATABASE_URL="postgresql://django_app:canary@db:5432/django_app",
            CELERY_BROKER_URL="amqp://broker.example.invalid/vhost",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CELERY_BROKER_URL must use Redis", result.stderr)

    def test_staging_valid_contract_uses_postgresql_and_debug_false(self):
        result = self._run_import(
            "config.settings.stg",
            "stg",
            DATABASE_URL="postgresql://django_app:canary@db:5432/django_app",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("stg", result.stdout)
        self.assertIn("django.db.backends.postgresql", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("False"))

    def test_staging_requires_s3_bucket(self):
        result = self._run_import(
            "config.settings.stg",
            "stg",
            DATABASE_URL="postgresql://django_app:canary@db:5432/django_app",
            AWS_STORAGE_BUCKET_NAME="",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("AWS_STORAGE_BUCKET_NAME is mandatory", result.stderr)

    def test_production_rejects_use_s3_storage_false(self):
        result = self._run_import(
            "config.settings.prod",
            "prod",
            DATABASE_URL="postgresql://django_app:canary@db:5432/django_app",
            USE_S3_STORAGE="false",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("USE_S3_STORAGE=false is forbidden in prod", result.stderr)

    def test_staging_requires_smtp_host(self):
        result = self._run_import(
            "config.settings.stg",
            "stg",
            DATABASE_URL="postgresql://django_app:canary@db:5432/django_app",
            SMTP_HOST="",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SMTP_HOST is mandatory", result.stderr)

    def test_production_requires_smtp_password(self):
        result = self._run_import(
            "config.settings.prod",
            "prod",
            DATABASE_URL="postgresql://django_app:canary@db:5432/django_app",
            SMTP_PASSWORD="",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SMTP_PASSWORD are mandatory", result.stderr)

    def test_application_name_default_and_override(self):
        # Default dst-ansible-django
        result_default = self._run_import("config.settings.dev", "dev")
        self.assertEqual(result_default.returncode, 0)

        # Explicit override
        result_override = self._run_import(
            "config.settings.dev",
            "dev",
            APPLICATION_NAME="mon-app-custom",
        )
        self.assertEqual(result_override.returncode, 0)


if __name__ == "__main__":
    unittest.main()
