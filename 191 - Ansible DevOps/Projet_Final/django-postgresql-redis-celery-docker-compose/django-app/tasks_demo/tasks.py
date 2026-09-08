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


@shared_task(name="tasks_demo.process_media_file")
def process_media_file(file_path: str):
    """Read an uploaded file from default_storage, process it, and write a report back."""
    import json
    from django.core.files.base import ContentFile
    from django.core.files.storage import default_storage

    if not default_storage.exists(file_path):
        return {
            "status": "error",
            "error": f"File not found: {file_path}",
        }

    with default_storage.open(file_path, "rb") as f:
        content = f.read()

    size_bytes = len(content)
    text_content = content.decode("utf-8", errors="replace")
    line_count = len(text_content.splitlines())
    word_count = len(text_content.split())

    report = {
        "file_path": file_path,
        "size_bytes": size_bytes,
        "line_count": line_count,
        "word_count": word_count,
        "processed_by": "celery_worker",
    }

    base_name = file_path.rsplit("/", 1)[-1]
    report_path = f"reports/{base_name}.json"
    report_content = ContentFile(json.dumps(report, indent=2).encode("utf-8"))
    saved_report_path = default_storage.save(report_path, report_content)

    return {
        "status": "success",
        "original_file": file_path,
        "report_file": saved_report_path,
        "size_bytes": size_bytes,
        "line_count": line_count,
        "word_count": word_count,
    }
