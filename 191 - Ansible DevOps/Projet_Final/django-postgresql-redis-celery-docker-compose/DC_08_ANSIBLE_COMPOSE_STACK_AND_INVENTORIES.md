# DC-08 — Ansible `compose_stack` + inventories DEV/STG/PROD

## Statut

```text
IMPLEMENTATION          ✅
ANSIBLE SYNTAX GREEN    ⏳
COMPOSE CONFIG GREEN    ⏳
RUNTIME QUALIFIED       ⏳
CI GREEN                ⏳
```

Ce jalon bascule l'orchestration active de la variante Docker Compose vers :

```text
common
  ↓
docker_engine
  ↓
compose_stack
```

Les anciens rôles systemd `postgresql`, `redis`, `django_app`, `celery`, `celery_beat` et `nginx` restent dans le repository comme référence historique, mais ne sont plus appelés par `playbooks/site.yml`.

## Rôle `compose_stack`

Le rôle déploie les définitions Compose dans :

```text
/opt/datascientest-compose/docker
```

et, uniquement en DEV Full, copie aussi le build context applicatif dans :

```text
/opt/datascientest-compose/django-app
```

La sélection d'overlay est déterministe :

```text
dev  → compose.yml + compose.dev.yml
stg  → compose.yml + compose.stg.yml
prod → compose.yml + compose.prod.yml
```

Aucun autre nom d'environnement n'est accepté.

## Contrat d'image

DEV accepte une image locale/taggée destinée au build local.

STG et PROD imposent :

```text
.+@sha256:[0-9a-fA-F]{64}
```

Une valeur `latest`, un tag de version seul ou le placeholder d'exemple fait échouer le preflight Ansible. Cela prépare la promotion stricte du même digest de STG vers PROD.

## Inventories

La structure cible est désormais :

```text
inventories/
├── dev/
│   ├── hosts.example.yml
│   ├── host_vars/server1.example.yml
│   └── group_vars/
│       ├── all.yml
│       └── vault.example.yml
├── stg/
│   └── ... même structure ...
└── prod/
    └── ... même structure ...
```

La topologie ne contient plus de groupe `database`. Un seul hôte `app` héberge Docker Engine et la stack Compose ; PostgreSQL est désormais un service du réseau Compose.

## Runtime environment

Chaque inventory construit le contrat `compose_stack_runtime_environment` à partir de variables non sensibles et des trois secrets Vault :

```text
vault_django_secret_key
vault_postgresql_password
vault_redis_password
```

Les URLs PostgreSQL et Redis sont construites avec `urlencode` avant injection. Le fichier distant :

```text
/opt/datascientest-compose/docker/.env.runtime
```

est rendu `root:root`, mode `0600`, avec `no_log: true`.

DC-09 renforcera la politique de secret lifecycle, de redaction, de rotation et les gates anti-fuite ; DC-08 pose le contrat nécessaire au déploiement.

## Admin/release one-off processes

Pour éviter le pattern `migrate` automatique dans chaque conteneur web, le rôle prépare `db`, `redis` et `web`, puis exécute séparément :

```text
python manage.py migrate --noinput
python manage.py collectstatic --noinput
python manage.py ensure_demo_periodic_task --seconds 30
```

Ces commandes sont exécutées via des conteneurs one-shot `docker compose run --rm --no-deps web ...`.

Elles sont annotées avec des règles `changed_when` destinées à préserver l'idempotence future : migrations déjà appliquées, staticfiles inchangés et PeriodicTask déjà conforme doivent rester non-mutants au second passage.

## Convergence Compose

Avant toute convergence :

```text
docker compose ... config --quiet
```

est exécuté avec le fichier runtime protégé.

La convergence finale utilise :

```text
community.docker.docker_compose_v2
state=present
wait=true
remove_orphans=true
```

DEV construit l'image via l'overlay local ; STG/PROD consomment l'image immuable et ne buildent jamais sur l'hôte de déploiement.

## Protection de la topologie

`site.yml` refuse désormais :

```text
plus ou moins d'un hôte app
présence d'un groupe database actif
```

Cela empêche de rejouer par erreur l'ancienne architecture mono-host native où le même serveur appartenait aux groupes `app` et `database`.

## Fichiers sensibles ignorés

`.gitignore` couvre maintenant les trois environnements :

```text
inventories/*/hosts.yml
inventories/*/host_vars/server1.yml
inventories/*/group_vars/vault.yml
.vault_pass
*.pem
*.key
```

Seuls les fichiers `.example.yml` restent versionnés.

## Limites actuelles

Aucune preuve runtime n'est encore revendiquée. Ce jalon ne prouve pas encore :

```text
ansible-playbook --syntax-check GREEN
docker compose config GREEN observé
build DEV Full réussi
pull STG/PROD réussi
migrations one-shot réussies
six services healthy
anti-SQLite runtime
network contract runtime
idempotence changed=0
```

Ces preuves seront apportées par DC-09 à DC-14.

## Prochain jalon

```text
DC-09 — Secure Runtime Configuration
```

Il renforcera Vault → runtime env, contrôles de longueur/placeholders, permissions, redaction, construction des URLs, absence de secrets dans Git/logs/artefacts et séparation stricte des secrets DEV/STG/PROD.
