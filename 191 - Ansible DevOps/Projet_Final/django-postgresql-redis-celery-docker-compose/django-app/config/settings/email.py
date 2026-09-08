import logging
from typing import Any, Dict

import environ
from django.core.exceptions import ImproperlyConfigured

logger = logging.getLogger(__name__)


def _smtp_email_config(env: environ.Env, environment_name: str) -> Dict[str, Any]:
    smtp_host = env("SMTP_HOST", default="").strip()
    if not smtp_host:
        raise ImproperlyConfigured(
            f"SMTP_HOST is mandatory for email in {environment_name}."
        )

    smtp_user = env("SMTP_USER", default="").strip()
    smtp_password = env("SMTP_PASSWORD", default="").strip()
    if not smtp_user or not smtp_password:
        raise ImproperlyConfigured(
            f"SMTP_USER and SMTP_PASSWORD are mandatory for email in {environment_name}."
        )

    use_tls = env.bool("SMTP_USE_TLS", default=False)
    use_ssl = env.bool("SMTP_USE_SSL", default=not use_tls)
    default_port = 587 if use_tls else 465
    smtp_port = env.int("SMTP_PORT", default=default_port)
    smtp_timeout = env.int("SMTP_TIMEOUT", default=10)

    default_from_email = env("DEFAULT_FROM_EMAIL", default=smtp_user).strip() or smtp_user
    server_email = env("SERVER_EMAIL", default=default_from_email).strip() or default_from_email

    imap_host = env("IMAP_HOST", default="").strip()
    imap_port = env.int("IMAP_PORT", default=993)
    imap_user = env("IMAP_USER", default=smtp_user).strip()
    imap_password = env("IMAP_PASSWORD", default=smtp_password).strip()
    imap_use_ssl = env.bool("IMAP_USE_SSL", default=True)
    imap_mailbox = env("IMAP_MAILBOX", default="INBOX").strip() or "INBOX"

    return {
        "EMAIL_BACKEND": "django.core.mail.backends.smtp.EmailBackend",
        "EMAIL_HOST": smtp_host,
        "EMAIL_PORT": smtp_port,
        "EMAIL_HOST_USER": smtp_user,
        "EMAIL_HOST_PASSWORD": smtp_password,
        "EMAIL_USE_TLS": use_tls,
        "EMAIL_USE_SSL": use_ssl,
        "EMAIL_TIMEOUT": smtp_timeout,
        "DEFAULT_FROM_EMAIL": default_from_email,
        "SERVER_EMAIL": server_email,
        # Inbound IMAP parameters
        "IMAP_HOST": imap_host,
        "IMAP_PORT": imap_port,
        "IMAP_USER": imap_user,
        "IMAP_PASSWORD": imap_password,
        "IMAP_USE_SSL": imap_use_ssl,
        "IMAP_MAILBOX": imap_mailbox,
    }


def development_email_settings(env: environ.Env) -> Dict[str, Any]:
    """DEV email policy: console.EmailBackend if SMTP is unconfigured, or smtp.EmailBackend if provided."""
    smtp_host = env("SMTP_HOST", default="").strip()
    smtp_user = env("SMTP_USER", default="").strip()

    if not smtp_host or not smtp_user:
        logger.info("DEV: SMTP_HOST/SMTP_USER unconfigured -> falling back to console.EmailBackend")
        return {
            "EMAIL_BACKEND": "django.core.mail.backends.console.EmailBackend",
            "EMAIL_HOST": "localhost",
            "EMAIL_PORT": 25,
            "EMAIL_HOST_USER": "",
            "EMAIL_HOST_PASSWORD": "",
            "EMAIL_USE_TLS": False,
            "EMAIL_USE_SSL": False,
            "EMAIL_TIMEOUT": 10,
            "DEFAULT_FROM_EMAIL": env("DEFAULT_FROM_EMAIL", default="dev-console@localhost"),
            "SERVER_EMAIL": env("SERVER_EMAIL", default="dev-console@localhost"),
            "IMAP_HOST": "",
            "IMAP_PORT": 993,
            "IMAP_USER": "",
            "IMAP_PASSWORD": "",
            "IMAP_USE_SSL": True,
            "IMAP_MAILBOX": "INBOX",
        }

    return _smtp_email_config(env, environment_name="dev")


def configure_email_settings(env: environ.Env, environment_name: str) -> Dict[str, Any]:
    """Configure email & IMAP settings according to the environment contract."""
    normalized_env = environment_name.lower().strip()
    if normalized_env == "dev":
        return development_email_settings(env)
    return _smtp_email_config(env, environment_name=normalized_env)
