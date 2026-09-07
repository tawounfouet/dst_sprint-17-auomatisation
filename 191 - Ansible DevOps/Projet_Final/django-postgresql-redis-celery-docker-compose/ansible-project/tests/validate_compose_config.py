#!/usr/bin/env python3
"""Validate a fully rendered Docker Compose configuration for DC-11.

The input must be the YAML produced by `docker compose config`. The validator
checks environment-specific invariants without requiring the containers to run.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import yaml

EXPECTED_SERVICES = {"nginx", "web", "db", "redis", "worker", "beat"}
APP_SERVICES = {"web", "worker", "beat"}
NO_PUBLISHED_PORT_SERVICES = {"web", "db", "redis", "worker", "beat"}


def fail(message: str) -> None:
    raise SystemExit(f"COMPOSE_CONFIG_FAIL: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def network_names(service: dict) -> set[str]:
    networks = service.get("networks") or {}
    if isinstance(networks, dict):
        return set(networks)
    return set(networks)


def has_no_new_privileges(service: dict) -> bool:
    return any(
        str(item).startswith("no-new-privileges")
        for item in service.get("security_opt", [])
    )


def volume_entries(service: dict) -> list[dict]:
    entries: list[dict] = []
    for item in service.get("volumes", []) or []:
        if isinstance(item, dict):
            entries.append(item)
        elif isinstance(item, str):
            source, _, target = item.partition(":")
            entries.append({"source": source, "target": target, "type": "unknown"})
    return entries


def validate(environment: str, config_path: Path) -> None:
    config = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    services = config.get("services") or {}
    networks = config.get("networks") or {}
    volumes = config.get("volumes") or {}

    require(set(services) == EXPECTED_SERVICES, "exactly six canonical services are required")
    require("frontend" in networks and "backend" in networks, "frontend/backend networks are required")
    require(bool(networks["backend"].get("internal")), "backend network must be internal")
    require({"postgres_data", "redis_data", "static_data"}.issubset(volumes), "named persistence volumes are missing")

    expected_networks = {
        "nginx": {"frontend"},
        "web": {"frontend", "backend"},
        "db": {"backend"},
        "redis": {"backend"},
        "worker": {"backend"},
        "beat": {"backend"},
    }
    for name, expected in expected_networks.items():
        require(network_names(services[name]) == expected, f"{name} network membership is invalid")

    images = {services[name].get("image") for name in APP_SERVICES}
    require(len(images) == 1 and None not in images, "web/worker/beat must use the same APP_IMAGE")
    app_image = next(iter(images))

    if environment == "dev":
        for name in APP_SERVICES:
            require(bool(services[name].get("build")), f"DEV Full requires build for {name}")
    else:
        require("@sha256:" in app_image, f"{environment} APP_IMAGE must be digest-pinned")
        digest = app_image.rsplit("@sha256:", 1)[-1]
        require(len(digest) == 64 and all(c in "0123456789abcdefABCDEF" for c in digest), "invalid APP_IMAGE digest")
        for name, service in services.items():
            require(not service.get("build"), f"{environment} must not build service {name}")

    for name in NO_PUBLISHED_PORT_SERVICES:
        require(not services[name].get("ports"), f"{name} must not publish host ports")

    nginx_ports = services["nginx"].get("ports") or []
    require(len(nginx_ports) == 1, "nginx must publish exactly one HTTP port in DC-11")
    port = nginx_ports[0]
    if isinstance(port, dict):
        target = int(port.get("target", 0))
        published = str(port.get("published", ""))
        host_ip = str(port.get("host_ip", ""))
    else:
        raw = str(port)
        parts = raw.split(":")
        target = int(parts[-1])
        published = parts[-2] if len(parts) >= 2 else ""
        host_ip = parts[0] if len(parts) >= 3 else ""
    require(target == 80, "nginx target port must be 80")
    if environment == "dev":
        require(published == "8080", "DEV Full nginx must publish port 8080")
        require(host_ip == "127.0.0.1", "DEV Full nginx must bind only to 127.0.0.1")
    else:
        require(published == "80", f"{environment} nginx must publish port 80")
        require(host_ip in {"", "0.0.0.0"}, f"{environment} nginx bind address is unexpected")

    for name in APP_SERVICES:
        service = services[name]
        require(service.get("read_only") is True, f"{name} root filesystem must be read-only")
        require(has_no_new_privileges(service), f"{name} must enable no-new-privileges")
        require("ALL" in (service.get("cap_drop") or []), f"{name} must drop all Linux capabilities")
        require(service.get("init") is True, f"{name} must enable init")

    for name in ("redis", "nginx"):
        service = services[name]
        require(service.get("read_only") is True, f"{name} root filesystem must be read-only")
        require(has_no_new_privileges(service), f"{name} must enable no-new-privileges")
        require("ALL" in (service.get("cap_drop") or []), f"{name} must drop all capabilities first")

    require(has_no_new_privileges(services["db"]), "db must enable no-new-privileges")
    require(services["redis"].get("user") == "redis", "Redis must run as the redis user")
    require("NET_BIND_SERVICE" in (services["nginx"].get("cap_add") or []), "Nginx requires only explicit capabilities")

    for name, service in services.items():
        require(service.get("restart") == "unless-stopped", f"{name} restart policy must be unless-stopped")
        require(bool(service.get("healthcheck")), f"{name} healthcheck is required")
        require(service.get("mem_limit") not in (None, ""), f"{name} memory limit is required")
        require(service.get("cpus") not in (None, ""), f"{name} CPU limit is required")
        require(service.get("pids_limit") not in (None, ""), f"{name} PID limit is required")
        logging = service.get("logging") or {}
        require(logging.get("driver") == "json-file", f"{name} must use json-file logging")
        options = logging.get("options") or {}
        require("max-size" in options and "max-file" in options, f"{name} log rotation is required")
        require(service.get("privileged") is not True, f"{name} must not be privileged")
        require(service.get("network_mode") != "host", f"{name} must not use host networking")
        require(service.get("pid") != "host", f"{name} must not use host PID namespace")
        for volume in volume_entries(service):
            target = str(volume.get("target", ""))
            source = str(volume.get("source", ""))
            require("docker.sock" not in target and "docker.sock" not in source, f"{name} must not mount Docker socket")
            if environment in {"stg", "prod"} and target == "/app":
                fail(f"{environment} must not bind-mount application source")

    worker_command = " ".join(map(str, services["worker"].get("command") or []))
    beat_command = " ".join(map(str, services["beat"].get("command") or []))
    require(" worker " in f" {worker_command} ", "Celery worker command missing")
    require(" -B " not in f" {worker_command} " and " --beat " not in f" {worker_command} ", "worker must not embed Beat")
    require(" beat " in f" {beat_command} ", "Celery Beat command missing")
    require("DatabaseScheduler" in beat_command, "Celery Beat must use django-celery-beat DatabaseScheduler")

    require("8000" in {str(v) for v in services["web"].get("expose", [])}, "web must expose container port 8000")
    require("5432" in {str(v) for v in services["db"].get("expose", [])}, "db must expose container port 5432")
    require("6379" in {str(v) for v in services["redis"].get("expose", [])}, "redis must expose container port 6379")

    print(f"COMPOSE_CONFIG_PASS: {environment}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("environment", choices=("dev", "stg", "prod"))
    parser.add_argument("config")
    args = parser.parse_args()
    validate(args.environment, Path(args.config))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
