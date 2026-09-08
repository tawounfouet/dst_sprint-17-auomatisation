import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")

app_name = os.environ.get("APPLICATION_NAME", "dst_ansible_django").replace("-", "_")
app = Celery(app_name)
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
