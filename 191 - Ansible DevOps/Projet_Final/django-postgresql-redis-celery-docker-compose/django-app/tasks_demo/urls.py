from django.urls import path

from .views import (
    submit_add,
    submit_database_probe,
    submit_email_task,
    submit_media_upload,
    submit_uppercase,
    task_status,
    trigger_imap_check,
)

urlpatterns = [
    path("api/tasks/add/", submit_add, name="task-add"),
    path("api/tasks/uppercase/", submit_uppercase, name="task-uppercase"),
    path("api/tasks/database-probe/", submit_database_probe, name="task-database-probe"),
    path("api/tasks/media-upload/", submit_media_upload, name="task-media-upload"),
    path("api/tasks/send-email/", submit_email_task, name="task-send-email"),
    path("api/tasks/imap-check/", trigger_imap_check, name="task-imap-check"),
    path("api/tasks/<str:task_id>/", task_status, name="task-status"),
]
