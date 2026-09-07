from pathlib import Path
from urllib.parse import urlsplit

import environ
from django.core.exceptions import ImproperlyConfigured

POSTGRESQL_ENGINE = "django.db.backends.postgresql"
POSTGRESQL_SCHEMES = {"postgres", "postgresql"}


def _postgresql_config(database_url: str) -> dict:
    scheme = urlsplit(database_url).scheme.lower()
    if scheme not in POSTGRESQL_SCHEMES:
        raise ImproperlyConfigured(
            "DATABASE_URL must use PostgreSQL (postgres:// or postgresql://)."
        )

    config = environ.Env.db_url_config(database_url)
    if config.get("ENGINE") != POSTGRESQL_ENGINE:
        raise ImproperlyConfigured(
            "DATABASE_URL must resolve to the Django PostgreSQL backend."
        )

    config["CONN_MAX_AGE"] = 60
    config["CONN_HEALTH_CHECKS"] = True
    return config


def development_database(env: environ.Env, base_dir: Path) -> dict:
    database_url = env("DATABASE_URL", default="").strip()
    if not database_url:
        return {
            "default": {
                "ENGINE": "django.db.backends.sqlite3",
                "NAME": base_dir / "db.sqlite3",
            }
        }

    return {"default": _postgresql_config(database_url)}


def required_postgresql_database(
    env: environ.Env,
    environment_name: str,
) -> dict:
    database_url = env("DATABASE_URL", default="").strip()
    if not database_url:
        raise ImproperlyConfigured(
            f"DATABASE_URL is mandatory in {environment_name}."
        )

    return {"default": _postgresql_config(database_url)}
