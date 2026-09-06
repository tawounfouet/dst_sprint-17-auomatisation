from django.db import connection
from django.http import JsonResponse
from django.views.decorators.http import require_GET


@require_GET
def home(request):
    return JsonResponse(
        {
            "application": "datascientest-ansible-django",
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
def info(request):
    return JsonResponse(
        {
            "application": "datascientest-ansible-django",
            "runtime": "gunicorn",
            "database": "postgresql",
        }
    )
