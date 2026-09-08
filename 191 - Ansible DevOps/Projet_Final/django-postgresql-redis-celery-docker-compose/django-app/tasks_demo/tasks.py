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


@shared_task(
    bind=True,
    name="tasks_demo.send_email_async",
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_kwargs={"max_retries": 5},
)
def send_email_async(
    self,
    to_email: str,
    subject: str,
    message: str,
    from_email: str = None,
    attachment_paths: list = None,
):
    """Asynchronously send an email without blocking the Web/Gunicorn process."""
    from django.conf import settings
    from django.core.mail import EmailMessage

    sender = from_email or getattr(settings, "DEFAULT_FROM_EMAIL", "webmaster@localhost")
    recipients = [to_email] if isinstance(to_email, str) else list(to_email)

    email = EmailMessage(
        subject=subject,
        body=message,
        from_email=sender,
        to=recipients,
    )

    if attachment_paths:
        from django.core.files.storage import default_storage

        for path in attachment_paths:
            if default_storage.exists(path):
                with default_storage.open(path, "rb") as f:
                    filename = path.rsplit("/", 1)[-1]
                    email.attach(filename, f.read())

    sent_count = email.send(fail_silently=False)
    return {
        "status": "sent",
        "to": recipients,
        "subject": subject,
        "sent_count": sent_count,
        "backend": getattr(settings, "EMAIL_BACKEND", "unknown"),
    }


@shared_task(name="tasks_demo.check_incoming_emails_imap")
def check_incoming_emails_imap():
    """Poll the IMAP mailbox for UNSEEN emails and stream attachments directly to default_storage."""
    import email
    import imaplib
    from email.header import decode_header

    from django.conf import settings
    from django.core.files.base import ContentFile
    from django.core.files.storage import default_storage

    imap_host = getattr(settings, "IMAP_HOST", "")
    imap_user = getattr(settings, "IMAP_USER", "")
    imap_password = getattr(settings, "IMAP_PASSWORD", "")
    imap_port = getattr(settings, "IMAP_PORT", 993)
    imap_use_ssl = getattr(settings, "IMAP_USE_SSL", True)
    imap_mailbox = getattr(settings, "IMAP_MAILBOX", "INBOX")

    if not imap_host or not imap_user:
        return {
            "status": "skipped",
            "reason": "imap_unconfigured",
        }

    client = (
        imaplib.IMAP4_SSL(imap_host, imap_port)
        if imap_use_ssl
        else imaplib.IMAP4(imap_host, imap_port)
    )
    try:
        client.login(imap_user, imap_password)
        client.select(imap_mailbox)
        status, messages = client.search(None, "UNSEEN")
        if status != "OK" or not messages or not messages[0]:
            return {
                "status": "success",
                "processed_count": 0,
                "emails": [],
            }

        email_ids = messages[0].split()
        processed = []
        for e_id in email_ids:
            res, msg_data = client.fetch(e_id, "(RFC822)")
            if res != "OK" or not msg_data:
                continue

            raw_email = msg_data[0][1]
            msg = email.message_from_bytes(raw_email)

            subject_header = msg.get("Subject", "")
            decoded_subject = ""
            for part, encoding in decode_header(subject_header):
                if isinstance(part, bytes):
                    decoded_subject += part.decode(encoding or "utf-8", errors="replace")
                else:
                    decoded_subject += part

            sender = msg.get("From", "")
            attachments = []
            for part in msg.walk():
                if part.get_content_disposition() == "attachment":
                    filename = part.get_filename() or "unnamed_attachment"
                    content = part.get_payload(decode=True)
                    if content:
                        saved_path = default_storage.save(
                            f"inbox_attachments/{e_id.decode()}_{filename}",
                            ContentFile(content),
                        )
                        attachments.append(saved_path)

            processed.append({
                "id": e_id.decode(),
                "from": sender,
                "subject": decoded_subject,
                "attachments": attachments,
            })

        return {
            "status": "success",
            "processed_count": len(processed),
            "emails": processed,
        }
    finally:
        try:
            client.close()
        except Exception:
            pass
        try:
            client.logout()
        except Exception:
            pass
