import os


def _positive_int(name: str, default: int) -> int:
    value = int(os.getenv(name, str(default)))
    if value <= 0:
        raise ValueError(f"{name} must be a positive integer")
    return value


bind = os.getenv("GUNICORN_BIND", "0.0.0.0:8000")
workers = _positive_int("WEB_CONCURRENCY", 2)
timeout = _positive_int("GUNICORN_TIMEOUT", 60)
graceful_timeout = _positive_int("GUNICORN_GRACEFUL_TIMEOUT", 30)
keepalive = _positive_int("GUNICORN_KEEPALIVE", 5)

accesslog = "-"
errorlog = "-"
capture_output = True

# Keep the runtime stateless: no PID file and no application log file are written
# into the container filesystem.
pidfile = None
