from pathlib import Path
from typing import Any, Dict

import environ
from django.core.exceptions import ImproperlyConfigured


def _s3_storage_config(env: environ.Env, environment_name: str) -> Dict[str, Any]:
    bucket_name = env("AWS_STORAGE_BUCKET_NAME", default="").strip()
    if not bucket_name:
        raise ImproperlyConfigured(
            f"AWS_STORAGE_BUCKET_NAME is mandatory when using S3 storage in {environment_name}."
        )

    access_key = env("AWS_ACCESS_KEY_ID", default="").strip()
    secret_key = env("AWS_SECRET_ACCESS_KEY", default="").strip()
    if not access_key or not secret_key:
        raise ImproperlyConfigured(
            f"AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are mandatory when using S3 storage in {environment_name}."
        )

    endpoint_url = env("AWS_S3_ENDPOINT_URL", default="").strip() or None
    addressing_style = env("AWS_S3_ADDRESSING_STYLE", default="auto").strip()
    region_name = env("AWS_S3_REGION_NAME", default="us-east-1").strip()
    querystring_auth = env.bool("AWS_QUERYSTRING_AUTH", default=True)

    options: Dict[str, Any] = {
        "access_key": access_key,
        "secret_key": secret_key,
        "bucket_name": bucket_name,
        "region_name": region_name,
        "addressing_style": addressing_style,
        "querystring_auth": querystring_auth,
        "file_overwrite": False,
        "location": "media",
    }
    if endpoint_url:
        options["endpoint_url"] = endpoint_url

    return {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": options,
        },
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
        },
    }


def development_storage(env: environ.Env, base_dir: Path) -> Dict[str, Any]:
    """DEV storage: local FileSystemStorage by default (DEV Lite), or S3 if USE_S3_STORAGE=true."""
    use_s3 = env.bool("USE_S3_STORAGE", default=False)
    if not use_s3:
        return {
            "default": {
                "BACKEND": "django.core.files.storage.FileSystemStorage",
                "OPTIONS": {
                    "location": base_dir / "mediafiles",
                },
            },
            "staticfiles": {
                "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
            },
        }
    return _s3_storage_config(env=env, environment_name="dev")


def required_s3_storage(env: environ.Env, environment_name: str) -> Dict[str, Any]:
    """STG / PROD storage: S3 storage is required, USE_S3_STORAGE=false is forbidden."""
    use_s3 = env.bool("USE_S3_STORAGE", default=True)
    if not use_s3:
        raise ImproperlyConfigured(
            f"USE_S3_STORAGE=false is forbidden in {environment_name}."
        )
    return _s3_storage_config(env=env, environment_name=environment_name)


def configure_storages(
    env: environ.Env,
    base_dir: Path,
    environment_name: str,
) -> Dict[str, Any]:
    """Universal dispatcher matching environment name."""
    if environment_name == "dev":
        return development_storage(env=env, base_dir=base_dir)
    return required_s3_storage(env=env, environment_name=environment_name)
