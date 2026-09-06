import subprocess
import json

"""
Outil pour récupérer les informations des instances Multipass locales.
Ce script remplace l'exemple AWS/Boto3 du cours original.
"""


def get_multipass_instances():
    try:
        result = subprocess.run(
            ["multipass", "list", "--format", "json"],
            capture_output=True,
            text=True,
        )
        data = json.loads(result.stdout)

        for instance in data["list"]:
            if instance["state"] == "Running":
                print(f"Name: {instance['name']}")
                print("Type: Multipass VM")
                print(f"State: {instance['state']}")
                print(
                    f"Private IP: "
                    f"{instance['ipv4'][0] if instance['ipv4'] else 'N/A'}"
                )
                print(f"OS: {instance['release']}")
                print("------")

    except Exception as exc:
        print(f"Erreur lors de la récupération des instances: {exc}")


if __name__ == "__main__":
    get_multipass_instances()
