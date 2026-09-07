from celery.result import AsyncResult
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.exceptions import ParseError
from rest_framework.response import Response

from .serializers import (
    AddTaskSerializer,
    TaskAcceptedSerializer,
    TaskStatusSerializer,
    UppercaseTaskSerializer,
)
from .tasks import add, database_probe, uppercase


def _accepted(task_result):
    payload = TaskAcceptedSerializer(
        {
            "task_id": task_result.id,
            "status": task_result.status,
        }
    )
    return Response(payload.data, status=status.HTTP_202_ACCEPTED)


def _validated_payload(request, serializer_class, error_code):
    try:
        payload = request.data
    except ParseError:
        return None, Response(
            {"error": "invalid_json"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    serializer = serializer_class(data=payload)
    if not serializer.is_valid():
        return None, Response(
            {"error": error_code},
            status=status.HTTP_400_BAD_REQUEST,
        )

    return serializer.validated_data, None


@api_view(["POST"])
def submit_add(request):
    payload, error_response = _validated_payload(
        request,
        AddTaskSerializer,
        "x_and_y_must_be_numbers",
    )
    if error_response is not None:
        return error_response

    return _accepted(add.delay(payload["x"], payload["y"]))


@api_view(["POST"])
def submit_uppercase(request):
    payload, error_response = _validated_payload(
        request,
        UppercaseTaskSerializer,
        "value_must_be_a_non_empty_string_up_to_1024_chars",
    )
    if error_response is not None:
        return error_response

    return _accepted(uppercase.delay(payload["value"]))


@api_view(["POST"])
def submit_database_probe(request):
    # Keep the baseline contract: this task has no input payload to validate.
    return _accepted(database_probe.delay())


@api_view(["GET"])
def task_status(request, task_id):
    result = AsyncResult(task_id)
    payload = {
        "task_id": task_id,
        "status": result.status,
    }

    if result.successful():
        payload["result"] = result.result
    elif result.failed():
        # Deliberately avoid returning Celery/backend exception details.
        payload["error"] = "task_failed"

    response = TaskStatusSerializer(payload)
    return Response(response.data, status=status.HTTP_200_OK)
