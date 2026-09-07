#!/usr/bin/env python3
"""Secret hygiene checks for repository files, logs/trees and ZIP artifacts.

The scanner intentionally favors high-confidence findings so it can run in CI
without dumping secret values. It never prints the matched value itself.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import zipfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
MAX_TEXT_BYTES = 2 * 1024 * 1024

FORBIDDEN_PATH_PATTERNS = [
    re.compile(r"(^|/)\.vault_pass(?:$|\.)"),
    re.compile(r"(^|/)\.env\.runtime$"),
    re.compile(
        r"(^|/)ansible-project/inventories/(dev|stg|prod)/(hosts\.yml|host_vars/server1\.yml|group_vars/vault\.yml)$"
    ),
    re.compile(r"(^|/)(id_rsa|id_ed25519)(?:$|\.)"),
    re.compile(r"\.(pem|key)$", re.IGNORECASE),
]

HIGH_CONFIDENCE_PATTERNS = [
    ("private key material", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b")),
    ("GitHub fine-grained token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{40,}\b")),
    ("Slack token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b")),
]

SENSITIVE_ASSIGNMENT = re.compile(
    r"(?mi)^\s*(DJANGO_SECRET_KEY|POSTGRES_PASSWORD|REDIS_PASSWORD|"
    r"vault_django_secret_key|vault_postgresql_password|vault_redis_password)"
    r"\s*[:=]\s*(.+?)\s*$"
)

ALLOWED_EXAMPLE_MARKERS = (
    "CHANGE_ME",
    "<SET_IN_ENCRYPTED_VAULT>",
    "{{",
    "${",
    "***",
    "REDACTED",
    "EXAMPLE",
    "STATIC_CHECK_ONLY",
    "...",
)

TEXT_ASSIGNMENT_SUFFIXES = {
    ".env",
    ".ini",
    ".log",
    ".txt",
    ".yaml",
    ".yml",
}


def forbidden_path(name: str) -> bool:
    normalized = name.replace("\\", "/")
    return any(pattern.search(normalized) for pattern in FORBIDDEN_PATH_PATTERNS)


def should_scan_assignments(name: str) -> bool:
    path = Path(name)
    if ".env" in path.name:
        return True
    return path.suffix.lower() in TEXT_ASSIGNMENT_SUFFIXES


def scan_text(name: str, text: str, known_values: list[str]) -> list[str]:
    findings: list[str] = []

    for label, pattern in HIGH_CONFIDENCE_PATTERNS:
        if pattern.search(text):
            findings.append(f"{label} detected in {name}")

    if should_scan_assignments(name):
        for match in SENSITIVE_ASSIGNMENT.finditer(text):
            raw_value = match.group(2).strip().strip('"\'')
            if not any(marker in raw_value for marker in ALLOWED_EXAMPLE_MARKERS):
                findings.append(
                    f"literal sensitive assignment for {match.group(1)} detected in {name}"
                )

    for value in known_values:
        if value and value in text:
            findings.append(f"known secret value detected in {name}")
            break

    return findings


def load_known_values(path: str | None) -> list[str]:
    if not path:
        return []
    values_path = Path(path)
    values = [line.rstrip("\r\n") for line in values_path.read_text().splitlines()]
    return [value for value in values if len(value) >= 8]


def read_text_file(path: Path) -> str | None:
    try:
        if not path.is_file() or path.stat().st_size > MAX_TEXT_BYTES:
            return None
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def scan_repo(known_values: list[str]) -> list[str]:
    repo_root = Path(
        subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=PROJECT_ROOT,
            text=True,
        ).strip()
    )
    project_rel = PROJECT_ROOT.relative_to(repo_root)
    result = subprocess.check_output(
        ["git", "ls-files", "-z", "--", str(project_rel)],
        cwd=repo_root,
    )

    findings: list[str] = []
    for raw_name in result.split(b"\0"):
        if not raw_name:
            continue
        tracked = Path(raw_name.decode("utf-8"))
        rel = tracked.relative_to(project_rel).as_posix()
        if forbidden_path(rel):
            findings.append(f"forbidden tracked path: {rel}")
            continue
        text = read_text_file(repo_root / tracked)
        if text is not None:
            findings.extend(scan_text(rel, text, known_values))
    return findings


def scan_tree(target: Path, known_values: list[str]) -> list[str]:
    findings: list[str] = []
    paths = [target] if target.is_file() else sorted(target.rglob("*"))
    for path in paths:
        if not path.is_file():
            continue
        try:
            rel = path.relative_to(target if target.is_dir() else target.parent).as_posix()
        except ValueError:
            rel = path.name
        if forbidden_path(rel):
            findings.append(f"forbidden path: {rel}")
            continue
        text = read_text_file(path)
        if text is not None:
            findings.extend(scan_text(rel, text, known_values))
    return findings


def scan_archive(target: Path, known_values: list[str]) -> list[str]:
    findings: list[str] = []
    with zipfile.ZipFile(target) as archive:
        for info in archive.infolist():
            name = info.filename.replace("\\", "/")
            if forbidden_path(name):
                findings.append(f"forbidden archive member: {name}")
                continue
            if info.is_dir() or info.file_size > MAX_TEXT_BYTES:
                continue
            try:
                text = archive.read(info).decode("utf-8")
            except UnicodeDecodeError:
                continue
            findings.extend(scan_text(name, text, known_values))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("repo", "tree", "archive"))
    parser.add_argument("target", nargs="?")
    parser.add_argument("--secret-values-file")
    args = parser.parse_args()

    known_values = load_known_values(args.secret_values_file)

    if args.mode == "repo":
        findings = scan_repo(known_values)
    else:
        if not args.target:
            parser.error("target is required for tree/archive modes")
        target = Path(args.target).resolve()
        if not target.exists():
            print(f"ERROR: target does not exist: {target}", file=sys.stderr)
            return 2
        findings = (
            scan_tree(target, known_values)
            if args.mode == "tree"
            else scan_archive(target, known_values)
        )

    if findings:
        for finding in findings:
            print(f"SECRET_HYGIENE_FAIL: {finding}", file=sys.stderr)
        return 1

    print(f"SECRET_HYGIENE_PASS: {args.mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
