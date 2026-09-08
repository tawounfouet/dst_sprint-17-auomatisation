import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import environ
from django.core.exceptions import ImproperlyConfigured

from config.settings.storage import configure_storages


class StorageConfigurationPolicyTests(unittest.TestCase):
    def test_dev_defaults_to_filesystem_storage_when_use_s3_is_false(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            with patch.dict(os.environ, {"USE_S3_STORAGE": "false"}, clear=True):
                storages = configure_storages(
                    env=environ.Env(),
                    base_dir=Path(tmp_dir),
                    environment_name="dev",
                )

        self.assertEqual(
            storages["default"]["BACKEND"],
            "django.core.files.storage.FileSystemStorage",
        )
        self.assertEqual(
            storages["default"]["OPTIONS"]["location"],
            Path(tmp_dir) / "mediafiles",
        )

    def test_dev_accepts_s3_storage_when_configured(self):
        env_vars = {
            "USE_S3_STORAGE": "true",
            "AWS_STORAGE_BUCKET_NAME": "test-bucket",
            "AWS_ACCESS_KEY_ID": "test-access-key",
            "AWS_SECRET_ACCESS_KEY": "test-secret-key",
            "AWS_S3_ENDPOINT_URL": "http://minio:9000",
            "AWS_S3_ADDRESSING_STYLE": "path",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            storages = configure_storages(
                env=environ.Env(),
                base_dir=Path("/tmp"),
                environment_name="dev",
            )

        self.assertEqual(
            storages["default"]["BACKEND"],
            "storages.backends.s3.S3Storage",
        )
        options = storages["default"]["OPTIONS"]
        self.assertEqual(options["bucket_name"], "test-bucket")
        self.assertEqual(options["access_key"], "test-access-key")
        self.assertEqual(options["secret_key"], "test-secret-key")
        self.assertEqual(options["endpoint_url"], "http://minio:9000")
        self.assertEqual(options["addressing_style"], "path")

    def test_s3_rejects_missing_bucket_name(self):
        env_vars = {
            "USE_S3_STORAGE": "true",
            "AWS_ACCESS_KEY_ID": "test-access-key",
            "AWS_SECRET_ACCESS_KEY": "test-secret-key",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            with self.assertRaises(ImproperlyConfigured) as ctx:
                configure_storages(
                    env=environ.Env(),
                    base_dir=Path("/tmp"),
                    environment_name="dev",
                )
            self.assertIn("AWS_STORAGE_BUCKET_NAME is mandatory", str(ctx.exception))

    def test_s3_rejects_missing_credentials(self):
        env_vars = {
            "USE_S3_STORAGE": "true",
            "AWS_STORAGE_BUCKET_NAME": "test-bucket",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            with self.assertRaises(ImproperlyConfigured) as ctx:
                configure_storages(
                    env=environ.Env(),
                    base_dir=Path("/tmp"),
                    environment_name="dev",
                )
            self.assertIn("AWS_ACCESS_KEY_ID", str(ctx.exception))

    def test_staging_forbids_use_s3_storage_false(self):
        with patch.dict(os.environ, {"USE_S3_STORAGE": "false"}, clear=True):
            with self.assertRaises(ImproperlyConfigured) as ctx:
                configure_storages(
                    env=environ.Env(),
                    base_dir=Path("/tmp"),
                    environment_name="stg",
                )
            self.assertIn("USE_S3_STORAGE=false is forbidden in stg", str(ctx.exception))

    def test_production_forbids_use_s3_storage_false(self):
        with patch.dict(os.environ, {"USE_S3_STORAGE": "false"}, clear=True):
            with self.assertRaises(ImproperlyConfigured) as ctx:
                configure_storages(
                    env=environ.Env(),
                    base_dir=Path("/tmp"),
                    environment_name="prod",
                )
            self.assertIn("USE_S3_STORAGE=false is forbidden in prod", str(ctx.exception))

    def test_s3_omits_endpoint_url_when_empty_or_none(self):
        env_vars = {
            "USE_S3_STORAGE": "true",
            "AWS_STORAGE_BUCKET_NAME": "cloud-bucket",
            "AWS_ACCESS_KEY_ID": "cloud-key",
            "AWS_SECRET_ACCESS_KEY": "cloud-secret",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            storages = configure_storages(
                env=environ.Env(),
                base_dir=Path("/tmp"),
                environment_name="prod",
            )
        self.assertNotIn("endpoint_url", storages["default"]["OPTIONS"])
