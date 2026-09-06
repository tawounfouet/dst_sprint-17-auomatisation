#!/usr/bin/env python3
"""Afficher les instances Multipass actives et leurs informations principales.

Ce script remplace, pour le lab local, le script AWS/Boto3 utilisé dans le
cours d'origine. Il doit être exécuté depuis une machine disposant de la
commande `multipass`.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys


def get_multipass_instances() -> int:
    """Affiche les VMs Multipass à l'état Running.

    Returns:
        0 si la commande est exécutée correctement, 1 sinon.
    """

    if shutil.which("multipass") is None:
        print("Erreur : la commande 'multipass' est introuvable dans le PATH.", file=sys.stderr)
        return 1

    try:
        result = subprocess.run(
            ["multipass", "list", "--format", "json"],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(result.stdout)
    except subprocess.CalledProcessError as exc:
        print(f"Erreur Multipass : {exc.stderr.strip() or exc}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"Erreur de décodage JSON : {exc}", file=sys.stderr)
        return 1

    running = [instance for instance in data.get("list", []) if instance.get("state") == "Running"]

    if not running:
        print("Aucune instance Multipass en cours d'exécution.")
        return 0

    for instance in running:
        ipv4 = instance.get("ipv4") or []
        print(f"Name: {instance.get('name', 'N/A')}")
        print("Type: Multipass VM")
        print(f"State: {instance.get('state', 'N/A')}")
        print(f"Private IP: {ipv4[0] if ipv4 else 'N/A'}")
        print(f"OS: {instance.get('release', 'N/A')}")
        print("------")

    return 0


if __name__ == "__main__":
    raise SystemExit(get_multipass_instances())
