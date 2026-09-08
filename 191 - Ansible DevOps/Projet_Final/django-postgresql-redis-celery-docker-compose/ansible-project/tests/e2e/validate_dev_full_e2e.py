#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import socket
import time
import urllib.error
import urllib.request
from typing import Any


def request_json(base_url: str, path: str, method: str = "GET", payload: Any = None) -> tuple[int, dict]:
    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        f"{base_url.rstrip('/')}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            body = response.read().decode("utf-8")
            return response.status, json.loads(body)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8")
        try:
            payload_json = json.loads(body)
        except json.JSONDecodeError:
            payload_json = {"raw": body}
        return exc.code, payload_json


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"DC12_VALIDATION_FAIL: {message}")


def submit_and_wait(base_url: str, path: str, payload: dict, expected: Any, label: str) -> None:
    status_code, accepted = request_json(base_url, path, method="POST", payload=payload)
    require(status_code == 202, f"{label} submission HTTP {status_code}")
    task_id = accepted.get("task_id")
    require(isinstance(task_id, str) and task_id, f"{label} task_id missing")

    deadline = time.monotonic() + 60
    final_payload = None
    while time.monotonic() < deadline:
        poll_code, polled = request_json(base_url, f"/api/tasks/{task_id}/")
        require(poll_code == 200, f"{label} status HTTP {poll_code}")
        task_status = polled.get("status")
        if task_status == "SUCCESS":
            final_payload = polled
            break
        if task_status == "FAILURE":
            raise SystemExit(f"DC12_VALIDATION_FAIL: {label} task failed")
        time.sleep(1)

    require(final_payload is not None, f"{label} task timeout")
    require(final_payload.get("result") == expected, f"{label} unexpected result")
    print(f"DC12_TASK_PASS: {label}")


def can_connect(host: str, port: int, timeout: float = 0.75) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the DC-12 DEV Full Compose runtime.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--public-port", type=int, default=8080)
    args = parser.parse_args()

    health_expectations = {
        "/health/": lambda body: body.get("status") == "healthy",
        "/health/database/": lambda body: body.get("status") == "healthy"
        and body.get("database") == "connected"
        and body.get("query") == 1,
        "/health/redis/": lambda body: body.get("status") == "healthy"
        and body.get("redis") == "connected",
        "/health/celery/": lambda body: body.get("status") == "healthy"
        and body.get("celery") == "connected"
        and int(body.get("workers", 0)) >= 1,
    }

    for path, predicate in health_expectations.items():
        code, body = request_json(args.base_url, path)
        require(code == 200, f"{path} HTTP {code}")
        require(predicate(body), f"{path} unhealthy payload")
    print("DC12_HTTP_PASS: health/database/redis/celery")

    code, info = request_json(args.base_url, "/api/info/")
    require(code == 200, f"/api/info/ HTTP {code}")
    expected_app_name = os.environ.get("APPLICATION_NAME", "dst-ansible-django")
    require(
        info.get("application") == expected_app_name,
        f"application identity mismatch: expected {expected_app_name}, got {info.get('application')}",
    )
    require(info.get("runtime") == "gunicorn", "runtime mismatch")
    require(info.get("database") == "postgresql", "database identity mismatch")
    require(info.get("broker") == "redis", "broker identity mismatch")
    require(info.get("async_runtime") == "celery", "async runtime mismatch")
    require(info.get("scheduler") == "django-celery-beat", "scheduler mismatch")
    print("DC12_HTTP_PASS: /api/info/")

    submit_and_wait(
        args.base_url,
        "/api/tasks/add/",
        {"x": 21, "y": 21},
        42,
        "add(21,21)=42",
    )
    submit_and_wait(
        args.base_url,
        "/api/tasks/uppercase/",
        {"value": "datascientest"},
        "DATASCIENTEST",
        "uppercase(datascientest)",
    )
    submit_and_wait(
        args.base_url,
        "/api/tasks/database-probe/",
        {},
        {"database": "connected", "query": 1},
        "database_probe SELECT 1",
    )

    require(can_connect("127.0.0.1", args.public_port), f"public Nginx port {args.public_port} is not reachable")
    print(f"DC12_NETWORK_PASS: 127.0.0.1:{args.public_port} reachable=true")

    for forbidden_port in (8000, 5432, 6379):
        require(
            not can_connect("127.0.0.1", forbidden_port),
            f"forbidden host port {forbidden_port} is reachable",
        )
        print(f"DC12_NETWORK_PASS: 127.0.0.1:{forbidden_port} reachable=false")

    print("DC12_RUNTIME_VALIDATION_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
