import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import environ
from django.core.exceptions import ImproperlyConfigured

from config.settings.database import (
    development_database,
    required_postgresql_database,
)


class DatabaseConfigurationPolicyTests(unittest.TestCase):
    def test_dev_falls_back_to_sqlite_when_database_url_is_missing(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            with patch.dict(os.environ, {}, clear=True):
                databases = development_database(
                    env=environ.Env(),
                    base_dir=Path(tmp_dir),
                )

        self.assertEqual(
            databases["default"]["ENGINE"],
            "django.db.backends.sqlite3",
        )

    def test_dev_accepts_postgresql_when_database_url_is_provided(self):
        with patch.dict(
            os.environ,
            {
                "DATABASE_URL": (
                    "postgresql://django_app:password@db:5432/django_app"
                )
            },
            clear=True,
        ):
            databases = development_database(
                env=environ.Env(),
                base_dir=Path("/tmp"),
            )

        self.assertEqual(
            databases["default"]["ENGINE"],
            "django.db.backends.postgresql",
        )
        self.assertEqual(databases["default"]["HOST"], "db")

    def test_dev_rejects_explicit_sqlite_database_url(self):
        with patch.dict(
            os.environ,
            {"DATABASE_URL": "sqlite:///unexpected.sqlite3"},
            clear=True,
        ):
            with self.assertRaises(ImproperlyConfigured):
                development_database(
                    env=environ.Env(),
                    base_dir=Path("/tmp"),
                )

    def test_staging_requires_database_url(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(ImproperlyConfigured):
                required_postgresql_database(
                    env=environ.Env(),
                    environment_name="staging",
                )

    def test_production_rejects_sqlite(self):
        with patch.dict(
            os.environ,
            {"DATABASE_URL": "sqlite:///forbidden.sqlite3"},
            clear=True,
        ):
            with self.assertRaises(ImproperlyConfigured):
                required_postgresql_database(
                    env=environ.Env(),
                    environment_name="production",
                )

    def test_production_accepts_postgresql(self):
        with patch.dict(
            os.environ,
            {
                "DATABASE_URL": (
                    "postgresql://django_app:password@db:5432/django_app"
                )
            },
            clear=True,
        ):
            databases = required_postgresql_database(
                env=environ.Env(),
                environment_name="production",
            )

        self.assertEqual(
            databases["default"]["ENGINE"],
            "django.db.backends.postgresql",
        )


if __name__ == "__main__":
    unittest.main()
