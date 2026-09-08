import os
from unittest import TestCase
from unittest.mock import patch

import environ
from django.core.exceptions import ImproperlyConfigured

from config.settings.email import configure_email_settings


class EmailSettingsPolicyTests(TestCase):
    def test_dev_fallback_to_console_when_unconfigured(self):
        with patch.dict(os.environ, {}, clear=True):
            config = configure_email_settings(environ.Env(), environment_name="dev")
            self.assertEqual(
                config["EMAIL_BACKEND"],
                "django.core.mail.backends.console.EmailBackend",
            )
            self.assertEqual(config["DEFAULT_FROM_EMAIL"], "dev-console@localhost")

    def test_dev_uses_smtp_when_credentials_provided(self):
        env_vars = {
            "SMTP_HOST": "pif.o2switch.net",
            "SMTP_PORT": "465",
            "SMTP_USER": "dev@awounfouet.com",
            "SMTP_PASSWORD": "secret_dev_pass",
            "SMTP_USE_SSL": "true",
            "SMTP_USE_TLS": "false",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            config = configure_email_settings(environ.Env(), environment_name="dev")
            self.assertEqual(
                config["EMAIL_BACKEND"],
                "django.core.mail.backends.smtp.EmailBackend",
            )
            self.assertEqual(config["EMAIL_HOST"], "pif.o2switch.net")
            self.assertEqual(config["EMAIL_PORT"], 465)
            self.assertTrue(config["EMAIL_USE_SSL"])
            self.assertFalse(config["EMAIL_USE_TLS"])
            self.assertEqual(config["EMAIL_HOST_USER"], "dev@awounfouet.com")

    def test_stg_fails_fast_when_smtp_host_missing(self):
        env_vars = {
            "SMTP_HOST": "",
            "SMTP_USER": "recette@gmail.com",
            "SMTP_PASSWORD": "some_app_password",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            with self.assertRaises(ImproperlyConfigured) as ctx:
                configure_email_settings(environ.Env(), environment_name="stg")
            self.assertIn("SMTP_HOST is mandatory", str(ctx.exception))

    def test_stg_fails_fast_when_smtp_password_missing(self):
        env_vars = {
            "SMTP_HOST": "smtp.gmail.com",
            "SMTP_USER": "recette@gmail.com",
            "SMTP_PASSWORD": "",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            with self.assertRaises(ImproperlyConfigured) as ctx:
                configure_email_settings(environ.Env(), environment_name="stg")
            self.assertIn("SMTP_PASSWORD are mandatory", str(ctx.exception))

    def test_stg_gmail_configuration(self):
        env_vars = {
            "SMTP_HOST": "smtp.gmail.com",
            "SMTP_PORT": "587",
            "SMTP_USER": "recette.monprojet@gmail.com",
            "SMTP_PASSWORD": "abcdefghijklmnop",
            "SMTP_USE_TLS": "true",
            "SMTP_USE_SSL": "false",
            "IMAP_HOST": "imap.gmail.com",
            "IMAP_PORT": "993",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            config = configure_email_settings(environ.Env(), environment_name="stg")
            self.assertEqual(config["EMAIL_BACKEND"], "django.core.mail.backends.smtp.EmailBackend")
            self.assertEqual(config["EMAIL_HOST"], "smtp.gmail.com")
            self.assertEqual(config["EMAIL_PORT"], 587)
            self.assertTrue(config["EMAIL_USE_TLS"])
            self.assertFalse(config["EMAIL_USE_SSL"])
            self.assertEqual(config["IMAP_HOST"], "imap.gmail.com")
            self.assertEqual(config["IMAP_PORT"], 993)
            self.assertTrue(config["IMAP_USE_SSL"])

    def test_prod_resend_configuration(self):
        env_vars = {
            "SMTP_HOST": "smtp.resend.com",
            "SMTP_PORT": "465",
            "SMTP_USER": "resend",
            "SMTP_PASSWORD": "re_live_test_api_key_12345",
            "SMTP_USE_SSL": "true",
            "SMTP_USE_TLS": "false",
            "DEFAULT_FROM_EMAIL": "notifications@example.com",
        }
        with patch.dict(os.environ, env_vars, clear=True):
            config = configure_email_settings(environ.Env(), environment_name="prod")
            self.assertEqual(config["EMAIL_BACKEND"], "django.core.mail.backends.smtp.EmailBackend")
            self.assertEqual(config["EMAIL_HOST"], "smtp.resend.com")
            self.assertEqual(config["EMAIL_PORT"], 465)
            self.assertTrue(config["EMAIL_USE_SSL"])
            self.assertFalse(config["EMAIL_USE_TLS"])
            self.assertEqual(config["EMAIL_HOST_USER"], "resend")
            self.assertEqual(config["DEFAULT_FROM_EMAIL"], "notifications@example.com")
