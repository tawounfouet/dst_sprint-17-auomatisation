# RC-13 — Rapport final de qualification

## Statut final

**PROJET QUALIFIÉ ✅**

Cette variante Ansible dérivée de `django-postgresql/` est désormais qualifiée dans sa topologie mono-host CI avec :

```text
Django
Gunicorn
Nginx
PostgreSQL
Redis
Celery Worker
django-celery-beat
```

La qualification finale repose sur le workflow :

```text
Ansible Django PostgreSQL Redis Celery Mono-Host Qualification
```

et sur le run canonique RC-12 :

```text
run      : #4
run ID   : 34099796947
job ID   : 101671354038
commit   : a7efa47d66a9b564bd36753f1dbdccbcb5cb7977
conclusion: success
```

---

## 1. Architecture qualifiée

```text
GitHub Actions runner
        │
        │ Ansible / community.docker.docker
        ▼
┌───────────────────────────────────────────┐
│ server1 — Ubuntu 24.04 + systemd          │
│                                           │
│ Nginx :80                                 │
│    │                                      │
│    ▼                                      │
│ Gunicorn 127.0.0.1:8000                   │
│    │                                      │
│    ▼                                      │
│ Django                                    │
│    ├──────────────► PostgreSQL             │
│    │                 127.0.0.1:5432       │
│    │                                      │
│    └──────────────► Redis                  │
│                      127.0.0.1:6379       │
│                         ▲                 │
│                         │                 │
│                   Celery Worker           │
│                         ▲                 │
│                         │                 │
│                  Celery Beat              │
│             DatabaseScheduler/PostgreSQL  │
└───────────────────────────────────────────┘
```

Le même `server1` appartient aux groupes Ansible `app` et `database`.

---

## 2. Rôles Ansible qualifiés

L'orchestration finale comprend sept rôles :

```text
common
postgresql
redis
django_app
celery
celery_beat
nginx
```

L'ordre du `site.yml` est :

```text
common
  ↓
postgresql
  ↓
redis
  ↓
django_app
  ↓
celery
  ↓
celery_beat
  ↓
nginx
```

Cette séquence garantit que PostgreSQL et Redis sont disponibles avant Django, puis que l'environnement Django et son `.venv` existent avant le démarrage du Worker et de Beat.

---

## 3. Contrats de sécurité observés

Le contrat réseau a été vérifié depuis le runner GitHub Actions vers l'adresse externe du conteneur `server1` :

```text
80    reachable=true
8000  reachable=false
5432  reachable=false
6379  reachable=false
```

La topologie qualifiée respecte donc :

```text
Nginx       → frontal accessible
Gunicorn    → localhost-only
PostgreSQL  → localhost-only
Redis       → localhost-only
```

Redis est configuré avec authentification, `protected-mode yes` et bind localhost. PostgreSQL reste en accès local avec utilisateur applicatif dédié et authentification SCRAM. Les secrets PostgreSQL, Django et Redis sont générés de façon éphémère dans la CI, chiffrés par Ansible Vault et supprimés au nettoyage du harness.

---

## 4. Validation runtime

La validation finale ne se limite pas à l'état des services. Elle contrôle réellement les chemins applicatifs et asynchrones.

Services observés `active` :

```text
postgresql
redis
datascientest-django
datascientest-celery
datascientest-celery-beat
nginx
```

Contrôles fonctionnels :

```text
Django liveness                     ✅
Django → PostgreSQL → SELECT 1      ✅
Django → Redis → PING               ✅
Django → Celery control ping        ✅
Nginx configuration                 ✅
```

---

## 5. Qualification des tâches Celery

### Tâche arithmétique

Le workflow soumet réellement :

```text
POST /api/tasks/add/
        ↓
Redis broker
        ↓
Celery Worker
        ↓
Redis result backend
        ↓
GET /api/tasks/<task_id>/
        ↓
SUCCESS / 42
```

Le résultat qualifié est :

```text
21 + 21 → 42
```

### Tâche PostgreSQL

Le workflow soumet également :

```text
POST /api/tasks/database-probe/
        ↓
Redis
        ↓
Celery Worker
        ↓
Django database connection
        ↓
psycopg
        ↓
PostgreSQL
        ↓
SELECT 1
```

Ce scénario prouve que le Worker ne fait pas seulement tourner une fonction Python isolée : il charge le contexte Django et atteint réellement PostgreSQL.

---

## 6. Qualification Django Celery Beat

`django-celery-beat` est intégré comme scheduler persistant :

```text
CELERY_BEAT_SCHEDULER = django_celery_beat.schedulers:DatabaseScheduler
```

Le management command idempotent crée le planning :

```text
datascientest-demo-heartbeat
```

associé à :

```text
tasks_demo.periodic_heartbeat
```

Le run de qualification a vérifié que la tâche périodique était activée et réellement déclenchée via les données persistées dans PostgreSQL.

Worker et Beat restent volontairement séparés en deux unités systemd :

```text
datascientest-celery.service
datascientest-celery-beat.service
```

Le pattern `worker -B` n'est pas utilisé.

---

## 7. Idempotence stricte

Le second déploiement du run final produit :

```text
localhost : ok=1  changed=0 unreachable=0 failed=0 skipped=0
server1   : ok=73 changed=0 unreachable=0 failed=0 skipped=3
```

Le harness impose ensuite :

```text
IDEMPOTENCE PASS: server1 changed=0
```

La stack est ensuite revalidée entièrement. Le second runtime recap reste :

```text
localhost : ok=1  changed=0 unreachable=0 failed=0
server1   : ok=37 changed=0 unreachable=0 failed=0
```

Le contrat réseau est également rejoué après le second provisioning.

---

## 8. Packaging final

Archive qualifiée :

```text
django-postgresql-redis-celery-ansible-20260907-082219.zip
```

SHA-256 du ZIP projet :

```text
558ef15ee8de57bf9d4ea09edcbdc586ff5a01c423c538de79119fb85df8ab8f
```

Contrôles :

```text
sha256sum -c       ✅ OK
PACKAGE SAFETY     ✅ PASS
```

Le package exclut l'inventaire runtime, le Vault réel, `.vault_pass`, les environnements Python locaux, fichiers `.env`, répertoires SSH et motifs de clés privées.

---

## 9. Artifact GitHub Actions

```text
name       : ansible-django-postgresql-redis-celery-qualified-34099796947
artifact ID: 10010158233
size       : 114672 bytes
created    : 2026-09-07T08:22:19Z
expires    : 2026-09-21T08:22:19Z
```

Digest de l'enveloppe GitHub :

```text
sha256:e70b25c19c0bbd5d0d69a5a20213398a6dd4b0ba157f3198b8e9febaf020f07c
```

URL de téléchargement :

```text
https://github.com/tawounfouet/dst_sprint-17-auomatisation/actions/runs/34099796947/artifacts/10010158233
```

Le digest de l'enveloppe GitHub n'est pas le SHA-256 du ZIP projet. La référence d'intégrité du livrable projet reste `558ef15e...ab8f`.

---

## 10. Ce qui est effectivement prouvé

```text
structure Ansible des 7 rôles                         ✅
syntaxe Bash / Python / YAML / Ansible                ✅
provisioning Ubuntu 24.04 mono-host                   ✅
PostgreSQL localhost-only                             ✅
Redis localhost-only + auth                           ✅
Django/Gunicorn                                       ✅
Nginx                                                 ✅
Celery Worker                                         ✅
django-celery-beat / DatabaseScheduler                ✅
round-trip Celery add                                 ✅
round-trip Celery → Django → PostgreSQL               ✅
PeriodicTask réellement exécutée                      ✅
contrat réseau                                        ✅
second site.yml changed=0                             ✅
validation post-idempotence                           ✅
ZIP + SHA-256                                         ✅
package safety gate                                   ✅
artifact GitHub Actions                               ✅
```

---

## 11. Limites de la qualification

Cette qualification est une qualification **CI mono-host avec transport Ansible Docker**. Elle ne constitue pas une preuve de déploiement sur un VPS public réel.

Restent hors preuve à ce stade :

```text
SSH distant vers un VPS réel
known_hosts / rotation de clés SSH
UFW / firewall cloud
DNS
HTTPS / Let's Encrypt
redirection HTTP → HTTPS
reboot complet du VPS et reprise des services
backup PostgreSQL
restore PostgreSQL
disaster recovery
supervision / alerting de production
haute disponibilité
scaling multi-worker / multi-host
```

Ces sujets constituent une éventuelle phase `PROD-LIKE` distincte et ne doivent pas être présentés comme déjà qualifiés.

---

## 12. Bilan du projet

Le projet initial Django/PostgreSQL a été dérivé sans casser sa baseline. La nouvelle variante a ajouté Redis et Celery de manière progressive, avec des contrats explicites, un scheduler Beat persistant et des tests fonctionnels réels.

Le résultat final démontre le pattern :

```text
HTTP
 ↓
Nginx
 ↓
Django
 ├──► PostgreSQL
 └──► Redis broker
          ↓
     Celery Worker
          ↓
     résultat Redis

Django Celery Beat
       ↓
DatabaseScheduler / PostgreSQL
       ↓
Redis broker
       ↓
Celery Worker
```

Le projet est donc **clos au niveau de la qualification CI prévue par la roadmap RC-00 → RC-13**.

## Statut de clôture

```text
RC-00   ✅
RC-01   ✅
RC-02   ✅
RC-03   ✅
RC-04   ✅
RC-05   ✅
RC-06   ✅
RC-06B  ✅
RC-07   ✅
RC-08   ✅
RC-09   ✅ GREEN
RC-10   ✅ GREEN
RC-11   ✅ GREEN
RC-12   ✅ GREEN
RC-13   ✅ CLOSED
```

**Django + PostgreSQL + Redis + Celery + django-celery-beat — qualification CI mono-host terminée.**
