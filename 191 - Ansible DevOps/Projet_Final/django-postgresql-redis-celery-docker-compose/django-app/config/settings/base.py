import os
from pathlib import Path

import environ
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parents[2]

env = environ.Env(
    DJANGO_DEBUG=(bool, False),
    CELERY_RESULT_EXPIRES=(int, 3600),
    CELERY_BEAT_MAX_LOOP_INTERVAL=(int, 5),
    CELERY_BEAT_SYNC_EVERY=(int, 1),
)

VALID_APPLICATION_ENVIRONMENTS = {"dev", "stg", "prod"}
SETTINGS_MODULE = os.environ.get("DJANGO_SETTINGS_MODULE", "config.settings.dev")
_settings_environment = SETTINGS_MODULE.rsplit(".", 1)[-1]
if _settings_environment not in VALID_APPLICATION_ENVIRONMENTS:
    _settings_environment = "dev"

APPLICATION_ENV = env("APPLICATION_ENV", default=_settings_environment).strip().lower()
if APPLICATION_ENV not in VALID_APPLICATION_ENVIRONMENTS:
    raise ImproperlyConfigured("APPLICATION_ENV must be one of: dev, stg, prod.")
if APPLICATION_ENV != _settings_environment:
    raise ImproperlyConfigured(
        "APPLICATION_ENV must match DJANGO_SETTINGS_MODULE "
        f"({APPLICATION_ENV!r} != {_settings_environment!r})."
    )

APPLICATION_VERSION = env("APPLICATION_VERSION", default="0.0.0-dev")
APPLICATION_COMMIT = env("APPLICATION_COMMIT", default="local")

SECRET_KEY = env("DJANGO_SECRET_KEY")
if APPLICATION_ENV in {"stg", "prod"}:
    if len(SECRET_KEY) < 50 or any(
        marker in SECRET_KEY
        for marker in ("CHANGE_ME", "REPLACE_ME", "SET_IN_ENCRYPTED_VAULT")
    ):
        raise ImproperlyConfigured(
            "DJANGO_SECRET_KEY must be a non-placeholder value of at least "
            "50 characters in staging and production."
        )

DEBUG = env.bool("DJANGO_DEBUG", default=False)
ALLOWED_HOSTS = env.list(
    "DJANGO_ALLOWED_HOSTS",
    default=["localhost", "127.0.0.1"],
)
CSRF_TRUSTED_ORIGINS = env.list(
    "DJANGO_CSRF_TRUSTED_ORIGINS",
    default=[],
)

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "django_celery_beat",
    "health.apps.HealthConfig",
    "tasks_demo.apps.TasksDemoConfig",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    }
]

WSGI_APPLICATION = "config.wsgi.application"

AUTH_PASSWORD_VALIDATORS = []
LANGUAGE_CODE = "fr-fr"
TIME_ZONE = "Europe/Paris"
USE_I18N = True
USE_TZ = True
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# The demo task API intentionally preserves the baseline public/anonymous
# contract. Authentication/authorization belongs to a later production API
# hardening milestone and must not be enabled implicitly during this migration.
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.AllowAny",
    ],
    "DEFAULT_PARSER_CLASSES": [
        "rest_framework.parsers.JSONParser",
    ],
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
}


def _required_runtime_url(name: str, dev_default: str) -> str:
    default = dev_default if APPLICATION_ENV == "dev" else ""
    value = env(name, default=default).strip()
    if not value:
        raise ImproperlyConfigured(f"{name} is mandatory in {APPLICATION_ENV}.")
    return value


CELERY_BROKER_URL = _required_runtime_url(
    "CELERY_BROKER_URL",
    "redis://127.0.0.1:6379/0",
)
CELERY_RESULT_BACKEND = _required_runtime_url(
    "CELERY_RESULT_BACKEND",
    "redis://127.0.0.1:6379/1",
)
if APPLICATION_ENV in {"stg", "prod"}:
    if not CELERY_BROKER_URL.startswith("redis://"):
        raise ImproperlyConfigured("CELERY_BROKER_URL must use Redis outside development.")
    if not CELERY_RESULT_BACKEND.startswith("redis://"):
        raise ImproperlyConfigured(
            "CELERY_RESULT_BACKEND must use Redis outside development."
        )

CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_IGNORE_RESULT = False
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP = True
CELERY_RESULT_EXPIRES = env.int("CELERY_RESULT_EXPIRES", default=3600)
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"
CELERY_BEAT_MAX_LOOP_INTERVAL = env.int(
    "CELERY_BEAT_MAX_LOOP_INTERVAL",
    default=5,
)
CELERY_BEAT_SYNC_EVERY = env.int("CELERY_BEAT_SYNC_EVERY", default=1)

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
        }
    },
    "root": {
        "handlers": ["console"],
        "level": env("DJANGO_LOG_LEVEL", default="INFO"),
    },
}
