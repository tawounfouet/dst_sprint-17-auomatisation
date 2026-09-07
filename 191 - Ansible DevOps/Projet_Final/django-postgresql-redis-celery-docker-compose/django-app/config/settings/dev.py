import os
from pathlib import Path

import environ

_DEV_ENV_FILE = Path(
    os.environ.get(
        "DJANGO_ENV_FILE",
        Path(__file__).resolve().parents[2] / ".env.dev",
    )
)

if _DEV_ENV_FILE.is_file():
    environ.Env.read_env(_DEV_ENV_FILE, overwrite=False)

from .base import *  # noqa: E402,F403
from .database import development_database  # noqa: E402

DEBUG = env.bool("DJANGO_DEBUG", default=True)
DATABASES = development_database(env=env, base_dir=BASE_DIR)

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
