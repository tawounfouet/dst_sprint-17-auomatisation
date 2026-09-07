from celery import shared_task
from django.db import connection
from django.utils import timezone


@shared_task(name="tasks_demo.add")
def add(x, y):
    return x + y


@shared_task(name="tasks_demo.uppercase")
def uppercase(value):
    return str(value).upper()


@shared_task(name="tasks_demo.database_probe")
def database_probe():
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        row = cursor.fetchone()

    return {
        "database": "connected",
        "query": row[0],
    }


@shared_task(name="tasks_demo.periodic_heartbeat")
def periodic_heartbeat():
    return {
        "status": "heartbeat",
        "timestamp": timezone.now().isoformat(),
    }
