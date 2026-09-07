import json

from celery.result import AsyncResult
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

from .tasks import add, database_probe, uppercase


def _json_body(request):
    try:
        return json.loads(request.body.decode("utf-8") or "{}")
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None


def _accepted(task_result):
    return JsonResponse(
        {
            "task_id": task_result.id,
            "status": task_result.status,
        },
        status=202,
    )


@csrf_exempt
@require_POST
def submit_add(request):
    payload = _json_body(request)
    if payload is None:
        return JsonResponse({"error": "invalid_json"}, status=400)

    x = payload.get("x")
    y = payload.get("y")
    numeric = (int, float)
    if (
        isinstance(x, bool)
        or isinstance(y, bool)
        or not isinstance(x, numeric)
        or not isinstance(y, numeric)
    ):
        return JsonResponse({"error": "x_and_y_must_be_numbers"}, status=400)

    return _accepted(add.delay(x, y))


@csrf_exempt
@require_POST
def submit_uppercase(request):
    payload = _json_body(request)
    if payload is None:
        return JsonResponse({"error": "invalid_json"}, status=400)

    value = payload.get("value")
    if not isinstance(value, str) or not value or len(value) > 1024:
        return JsonResponse(
            {"error": "value_must_be_a_non_empty_string_up_to_1024_chars"},
            status=400,
        )

    return _accepted(uppercase.delay(value))


@csrf_exempt
@require_POST
def submit_database_probe(request):
    return _accepted(database_probe.delay())


@require_GET
def task_status(request, task_id):
    result = AsyncResult(task_id)
    response = {
        "task_id": task_id,
        "status": result.status,
    }

    if result.successful():
        response["result"] = result.result
    elif result.failed():
        response["error"] = "task_failed"

    return JsonResponse(response)
