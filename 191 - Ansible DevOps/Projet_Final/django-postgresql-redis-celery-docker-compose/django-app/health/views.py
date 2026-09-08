import redis as redis_client
from django.conf import settings
from django.db import connection
from django.http import JsonResponse
from django.views.decorators.http import require_GET

from config.celery import app as celery_app


@require_GET
def home(request):
    return JsonResponse(
        {
            "application": getattr(settings, "APPLICATION_NAME", "dst-ansible-django"),
            "status": "running",
        }
    )


@require_GET
def health(request):
    return JsonResponse({"status": "healthy"})


@require_GET
def database_health(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            value = cursor.fetchone()[0]
    except Exception:
        return JsonResponse(
            {"status": "unhealthy", "database": "disconnected"},
            status=503,
        )

    return JsonResponse(
        {"status": "healthy", "database": "connected", "query": value}
    )


@require_GET
def redis_health(request):
    client = None
    try:
        client = redis_client.from_url(
            settings.CELERY_BROKER_URL,
            socket_connect_timeout=1,
            socket_timeout=1,
            decode_responses=True,
        )
        redis_ok = bool(client.ping())
    except Exception:
        redis_ok = False
    finally:
        if client is not None:
            client.close()

    if not redis_ok:
        return JsonResponse(
            {"status": "unhealthy", "redis": "disconnected"},
            status=503,
        )

    return JsonResponse({"status": "healthy", "redis": "connected"})


@require_GET
def celery_health(request):
    try:
        responses = celery_app.control.ping(timeout=2.0)
    except Exception:
        responses = []

    if not responses:
        return JsonResponse(
            {"status": "unhealthy", "celery": "unavailable", "workers": 0},
            status=503,
        )

    return JsonResponse(
        {
            "status": "healthy",
            "celery": "connected",
            "workers": len(responses),
        }
    )


@require_GET
def info(request):
    return JsonResponse(
        {
            "application": getattr(settings, "APPLICATION_NAME", "dst-ansible-django"),
            "runtime": "gunicorn",
            "database": "postgresql",
            "broker": "redis",
            "async_runtime": "celery",
            "scheduler": "django-celery-beat",
        }
    )
