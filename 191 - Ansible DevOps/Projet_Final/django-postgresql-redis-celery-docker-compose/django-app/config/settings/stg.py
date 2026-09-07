from django.core.exceptions import ImproperlyConfigured

from .base import *  # noqa: F403
from .database import required_postgresql_database

if env.bool("DJANGO_DEBUG", default=False):
    raise ImproperlyConfigured("DJANGO_DEBUG=true is forbidden in staging.")

DEBUG = False
DATABASES = required_postgresql_database(
    env=env,
    environment_name="staging",
)

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
