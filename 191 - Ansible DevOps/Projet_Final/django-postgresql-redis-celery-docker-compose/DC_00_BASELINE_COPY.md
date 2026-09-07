# DC-00 — Copie contrôlée de la baseline

## Statut

**COPIE CRÉÉE ✅ — QUALIFICATION DOCKER COMPOSE NON ACQUISE**

## Source

La nouvelle variante part de la baseline :

```text
191 - Ansible DevOps/Projet_Final/django-postgresql-redis-celery/
```

au commit :

```text
0b33d1ea230b47492720127b2dcf837899da851d
```

Cette baseline est qualifiée pour une installation mono-host native/systemd avec PostgreSQL, Redis, Gunicorn, Celery Worker, Celery Beat et Nginx.

## Cible

Le nouveau dossier est :

```text
191 - Ansible DevOps/Projet_Final/django-postgresql-redis-celery-docker-compose/
```

La branche dédiée est :

```text
feat/ansible-django-postgresql-redis-celery-docker-compose
```

## Ce qui est conservé

La copie conserve volontairement :

```text
application Django
configuration Celery
services health et API asynchrone
rôles Ansible historiques
playbooks et scripts
structure de tests
exemples d'inventaire/Vault
documentation RC historique
structure evidence/
```

Les rôles historiques sont des références de migration. Ils ne devront pas être exécutés en parallèle avec les futurs conteneurs pour fournir les mêmes services.

## Ce qui n'est pas hérité

Le statut GREEN précédent ne s'applique pas à cette variante.

Les éléments suivants doivent être requalifiés :

```text
construction de l'image applicative
Docker Engine
Docker Compose
réseau inter-conteneurs
PostgreSQL conteneurisé
Redis authentifié conteneurisé
Gunicorn dans web
Nginx conteneurisé
Celery Worker conteneurisé
Celery Beat conteneurisé
DRF
volumes persistants
healthchecks
idempotence Ansible/Compose
package final
```

Les fichiers `RC_*.md` présents dans la copie constituent uniquement l'historique de la baseline.

## Invariant de sécurité

La nouvelle cible ne doit publier vers l'hôte que le reverse proxy :

```text
80    → publié
8000  → non publié
5432  → non publié
6379  → non publié
```

Aucun secret réel ne doit entrer dans le Dockerfile, le fichier Compose, Git ou les logs. `.env` restera ignoré ; seuls des exemples sans secrets pourront être versionnés.

## Definition of Done DC-00

```text
branche dédiée créée                       ✅
dossier distinct créé                      ✅
baseline copiée                            ✅
source inchangée                           ✅
qualification précédente explicitement reset ✅
roadmap Docker Compose créée               ✅
prochaine étape identifiée                 ✅ DC-01/DC-02
```
