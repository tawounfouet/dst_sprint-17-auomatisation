# Plan d'implémentation V2 — Django/DRF multi-environnement + Docker Compose + Ansible + 12-Factor

> **Statut : plan canonique de la variante Docker Compose**
>
> Ce document remplace le premier plan d'implémentation Docker Compose et intègre les décisions prises après le bootstrap de la variante : `django-environ`, gestion `dev/stg/prod`, fallback SQLite strictement limité au développement, Django REST Framework, Docker/Compose, Ansible/Vault et alignement explicite avec les principes 12-Factor App.

---

## 1. Objectif général

Faire évoluer la baseline qualifiée :

```text
Django
PostgreSQL
Redis + authentification
Gunicorn
Nginx
Celery Worker
Celery Beat + django-celery-beat
Ansible
```

vers une variante conteneurisée et multi-environnement :

```text
Django + Django REST Framework
Gunicorn
PostgreSQL
Redis + authentification
Celery Worker
Celery Beat + django-celery-beat
Nginx
Docker Engine
Docker Compose v2
Ansible
Ansible Vault
django-environ
```

avec trois environnements applicatifs explicites :

```text
dev
stg
prod
```

et deux modes de développement :

```text
DEV Lite  → Django local + SQLite autorisé
DEV Full  → Docker Compose + PostgreSQL + Redis + Celery + Nginx
```

La cible doit être conçue pour que **STG soit proche de PROD**, que l'image Docker soit **immutable et promue entre environnements**, et qu'aucun fallback silencieux ne puisse masquer une panne PostgreSQL en staging ou en production.

---

## 2. Principe fondamental : séparation des responsabilités

```text
Git / CI
  └── construit l'artefact applicatif immutable

Ansible
  ├── prépare Ubuntu
  ├── installe Docker Engine + Compose v2
  ├── sélectionne l'environnement
  ├── injecte la configuration runtime
  ├── fournit les secrets depuis Vault
  ├── déploie/converge Compose
  └── exécute les validations

Docker Compose
  ├── décrit la topologie des services
  ├── porte les variables runtime
  ├── gère réseaux/volumes/healthchecks
  └── démarre les process types

Django / django-environ
  ├── lit et caste la configuration
  ├── sélectionne le module de settings
  └── applique les politiques applicatives

PostgreSQL / Redis
  └── backing services externes au process applicatif
```

`django-environ` est un **parser de configuration**, pas un gestionnaire de secrets.

Ansible Vault reste la source de secrets pour les environnements gérés par Ansible.

---

## 3. Baseline et non-héritage des preuves

La variante est copiée depuis le projet qualifié :

```text
django-postgresql-redis-celery/
```

mais sa qualification GREEN n'est **pas héritée**.

La nouvelle cible modifie notamment :

```text
runtime systemd natif → Docker Compose
settings.py unique → settings multi-environnement
os.getenv direct → django-environ
Django JSON views → DRF pour l'API asynchrone
localhost service discovery → DNS Compose
processes natifs → containers/process types
```

La nouvelle variante devra donc produire ses propres preuves de :

```text
static validation
runtime
network isolation
Celery
Celery Beat
multi-environment policy
SQLite prohibition STG/PROD
idempotence
packaging
```

---

## 4. Architecture cible

```text
                         Client / Internet
                                │
                                │ :80 / :443
                                ▼
┌────────────────────────────────────────────────────────────┐
│ Ubuntu 24.04                                               │
│                                                            │
│  Docker Engine                                             │
│                                                            │
│  ┌──────────────── Docker Compose ───────────────────────┐  │
│  │                                                      │  │
│  │                    nginx                             │  │
│  │                      │                               │  │
│  │                      ▼                               │  │
│  │                     web                              │  │
│  │             Django / DRF / Gunicorn                 │  │
│  │                  0.0.0.0:8000                       │  │
│  │                 ┌────┴────┐                         │  │
│  │                 │         │                         │  │
│  │                 ▼         ▼                         │  │
│  │                db       redis                       │  │
│  │           PostgreSQL   Redis + auth                 │  │
│  │             :5432        :6379                      │  │
│  │                 ▲          ▲                        │  │
│  │                 │          │                        │  │
│  │                 ├── worker ┤                        │  │
│  │                 │  Celery  │                        │  │
│  │                 │          │                        │  │
│  │                 └── beat ──┘                        │  │
│  │               Celery Beat                           │  │
│  │          django-celery-beat                         │  │
│  │          DatabaseScheduler                          │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

Services Compose persistants :

```text
nginx
web
db
redis
worker
beat
```

`web`, `worker` et `beat` doivent utiliser **la même image applicative**.

---

## 5. Conventions de configuration Django

### 5.1 `django-environ`

Le projet utilisera :

```text
django-environ
```

et non un double empilement :

```text
python-dotenv + django-environ
```

`django-environ` couvre déjà la lecture optionnelle d'un fichier `.env` en développement local ainsi que le casting des valeurs.

### 5.2 Structure cible des settings

```text
django-app/
└── config/
    ├── settings/
    │   ├── __init__.py
    │   ├── base.py
    │   ├── database.py
    │   ├── dev.py
    │   ├── stg.py
    │   └── prod.py
    ├── celery.py
    ├── urls.py
    └── wsgi.py
```

### 5.3 Responsabilités

`base.py` contient les paramètres communs :

```text
INSTALLED_APPS
MIDDLEWARE
TEMPLATES
LANGUAGE_CODE
TIME_ZONE
STATIC
DRF defaults
Celery defaults
logging stdout/stderr
APPLICATION_* metadata
```

`database.py` contient exclusivement la politique de sélection/validation de la base.

`dev.py`, `stg.py`, `prod.py` expriment les différences de comportement propres aux environnements.

Le choix de l'environnement est explicite :

```text
DJANGO_SETTINGS_MODULE=config.settings.dev
DJANGO_SETTINGS_MODULE=config.settings.stg
DJANGO_SETTINGS_MODULE=config.settings.prod
```

---

## 6. Politique DATABASE_URL et fallback SQLite

Cette politique est **non négociable**.

### 6.1 Contrat

```text
DEV + DATABASE_URL absente
    → SQLite autorisé

DEV + DATABASE_URL présente
    → doit être PostgreSQL

STG + DATABASE_URL absente
    → échec de démarrage

STG + DATABASE_URL SQLite
    → échec de démarrage

PROD + DATABASE_URL absente
    → échec de démarrage

PROD + DATABASE_URL SQLite
    → échec de démarrage

STG/PROD + DATABASE_URL PostgreSQL
    → autorisé
```

### 6.2 Interdiction absolue du fallback de connectivité

Le projet ne doit **jamais** implémenter :

```python
try:
    connect_to_postgres()
except Exception:
    use_sqlite()
```

Une panne PostgreSQL en STG/PROD doit provoquer un échec visible.

Le fallback SQLite dépend uniquement de l'**absence volontaire de `DATABASE_URL` dans `config.settings.dev`**.

### 6.3 DEV Lite versus DEV Full

```text
DEV Lite
  Django local
  DATABASE_URL absente
  SQLite
  usage : développement rapide / tests ciblés

DEV Full
  Docker Compose
  DATABASE_URL=postgresql://...@db:5432/...
  PostgreSQL
  Redis
  Worker
  Beat
  Nginx
  usage : intégration / parité
```

SQLite ne doit pas devenir la base partagée entre plusieurs conteneurs `web`, `worker` et `beat`.

---

## 7. Variables d'environnement applicatives

Contrat minimum :

```text
APPLICATION_ENV
APPLICATION_VERSION
APPLICATION_COMMIT

DJANGO_SETTINGS_MODULE
DJANGO_SECRET_KEY
DJANGO_DEBUG
DJANGO_ALLOWED_HOSTS
DJANGO_CSRF_TRUSTED_ORIGINS

DATABASE_URL

CELERY_BROKER_URL
CELERY_RESULT_BACKEND
CELERY_RESULT_EXPIRES
```

`APPLICATION_ENV` accepte uniquement :

```text
dev
stg
prod
```

Il sert surtout à l'observabilité et au diagnostic ; il ne doit pas devenir un gros switch conditionnel dispersé dans le code.

---

## 8. Fichiers `.env`

Le repository ne doit jamais contenir de vrais secrets.

Fichiers versionnés :

```text
.env.dev.example
.env.stg.example
.env.prod.example
```

Fichiers ignorés :

```text
.env
.env.dev
.env.stg
.env.prod
.env.runtime
.env.*.runtime
```

### DEV local

`django-environ` peut charger un `.env.dev` local.

### STG / PROD

Le runtime environment est généré/injecté par Ansible à partir de l'inventory et de Vault.

Aucune valeur de production réelle ne doit être committée.

---

## 9. Django REST Framework

Le projet ajoutera une dépendance bornée :

```text
djangorestframework
```

et `rest_framework` dans `INSTALLED_APPS`.

Les endpoints asynchrones seront migrés réellement vers DRF :

```text
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

La validation doit couvrir :

```text
serializers / validation
HTTP status codes
invalid payloads
submission Celery
poll task result
failed task without leakage d'exception
```

Les health endpoints peuvent rester des vues Django simples s'ils ne bénéficient pas de DRF.

---

## 10. Image Docker applicative

### 10.1 Une image commune

```text
                   django-app image
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
             web        worker       beat
          Gunicorn      Celery      Celery Beat
```

### 10.2 Dockerfile

Le Dockerfile devra :

```text
utiliser une image Python 3.12 appropriée
pinner autant que raisonnable la base runtime
copier requirements avant le code pour le cache
installer les dépendances au build
ne pas faire de pip install au runtime
copier le code applicatif
créer un utilisateur non-root
exécuter les process applicatifs non-root
ne contenir aucun secret
ne contenir aucun .env réel
préparer static/runtime dirs avec permissions minimales
émettre les logs vers stdout/stderr
supporter SIGTERM proprement
```

L'image Docker n'a pas besoin d'un `.venv` interne supplémentaire ; l'isolation du conteneur remplit ce rôle dans cette variante.

### 10.3 Artefact immutable

Cible :

```text
Git commit
   ↓
CI build
   ↓
image tag + immutable digest
   ↓
STG
   ↓
PROD
```

STG et PROD doivent utiliser **la même image/digest** lors d'une promotion donnée.

---

## 11. Docker Compose multi-environnement

Structure cible :

```text
docker/
├── compose.yml
├── compose.dev.yml
├── compose.stg.yml
├── compose.prod.yml
└── nginx/
    └── default.conf
```

### 11.1 `compose.yml`

Contient les éléments communs :

```text
services
networks
volumes
healthchecks communs
commandes communes
image references
```

### 11.2 DEV

`compose.dev.yml` peut autoriser des facilités de développement, par exemple :

```text
bind mount du code si explicitement voulu
ports locaux restreints à 127.0.0.1
outils de debug
```

Le DEV Full utilise PostgreSQL.

### 11.3 STG

STG doit être prod-like :

```text
DEBUG=false
pas de bind mount code
pas de SQLite
pas de ports DB/Redis/Gunicorn publiés
même topologie que PROD
```

### 11.4 PROD

PROD applique les protections les plus strictes :

```text
DEBUG=false
PostgreSQL obligatoire
Redis authentifié
aucun bind mount du code
image immutable
secrets externes
HTTPS/UFW dans une phase prod-like ultérieure si non encore implémentés
```

---

## 12. Service discovery Compose

Les services ne doivent pas utiliser `127.0.0.1` pour joindre les autres conteneurs.

Contrat :

```text
nginx  → web:8000
web    → db:5432
web    → redis:6379
worker → db:5432
worker → redis:6379
beat   → db:5432
beat   → redis:6379
```

Gunicorn écoute :

```text
0.0.0.0:8000
```

**dans le conteneur**, sans publication hôte du port 8000.

---

## 13. Contrat réseau

Publication hôte :

```text
nginx : 80:80
```

et plus tard éventuellement :

```text
443:443
```

Interdiction de publier sur l'hôte en STG/PROD :

```text
8000 Gunicorn
5432 PostgreSQL
6379 Redis
```

Contrat E2E attendu :

```text
80    published=true
8000  published=false
5432  published=false
6379  published=false
```

`expose:` peut documenter les ports internes mais ne constitue pas à lui seul un mécanisme de sécurité.

---

## 14. PostgreSQL

PostgreSQL devient un backing service Compose dans cette variante.

Exigences :

```text
volume nommé persistant
healthcheck pg_isready
user applicatif dédié
database dédiée
mot de passe injecté
pas de port hôte en STG/PROD
DATABASE_URL utilisée par Django/worker/beat
```

La politique de restauration/backup production reste une phase ultérieure si elle n'est pas qualifiée dans cette roadmap.

---

## 15. Redis + authentification

Redis doit conserver une authentification obligatoire dans DEV Full/STG/PROD.

Exigences :

```text
requirepass / configuration équivalente
aucun port 6379 publié en STG/PROD
PING authentifié dans les validations
broker DB /0
result backend DB /1
secret jamais affiché dans les logs
```

URLs cibles :

```text
CELERY_BROKER_URL=redis://:<url-encoded-secret>@redis:6379/0
CELERY_RESULT_BACKEND=redis://:<url-encoded-secret>@redis:6379/1
```

Le mot de passe doit être correctement URL-encodé lors de la construction des URLs.

---

## 16. Celery Worker et Celery Beat

Worker :

```text
celery -A config worker --loglevel=INFO
```

Beat :

```text
celery -A config beat \
  --scheduler django_celery_beat.schedulers:DatabaseScheduler \
  --loglevel=INFO
```

Interdiction du pattern :

```text
celery worker -B
```

Worker et Beat restent deux process types séparés.

Beat stocke son scheduling durable via `django-celery-beat` / PostgreSQL et non dans un fichier local critique `celerybeat-schedule`.

---

## 17. Persistance et statelessness

Volumes nommés minimum :

```text
postgres_data
static_data
```

Redis :

```text
redis_data
```

uniquement si la politique AOF/RDB retenue exige une persistance explicite.

Le process applicatif doit rester aussi stateless que possible.

Interdiction de dépendre de fichiers locaux du container pour :

```text
sessions métier
état Celery critique
uploads durables
état applicatif durable
```

Si des uploads/media deviennent nécessaires, prévoir un backing service dédié ou un volume/stockage objet explicitement qualifié.

---

## 18. Logging 12-Factor

Tous les services applicatifs doivent écrire vers stdout/stderr :

```text
Django
Gunicorn
Celery Worker
Celery Beat
Nginx
```

Pas de logique applicative de rotation de fichiers de logs dans les conteneurs.

Le backend futur peut être :

```text
Docker logging driver
Loki
ELK / OpenSearch
Azure Monitor
CloudWatch
```

mais ce choix est séparé de l'application.

Les logs pourront inclure :

```text
APPLICATION_ENV
APPLICATION_VERSION
APPLICATION_COMMIT
```

sans inclure de secrets.

---

## 19. Healthchecks et runtime validation

Healthchecks techniques :

```text
db     → pg_isready
redis  → PING authentifié
web    → GET /health/
nginx  → GET local /health/
```

Worker/Beat ne doivent pas être qualifiés uniquement avec un `ps`.

Validation fonctionnelle obligatoire :

```text
Celery control ping
add(21,21) → 42
uppercase("datascientest") → "DATASCIENTEST"
database_probe() → PostgreSQL → SELECT 1
PeriodicTask Beat réellement déclenchée
```

---

## 20. Disposability

Les containers/process types doivent :

```text
démarrer rapidement
échouer clairement si une dépendance/config obligatoire manque
recevoir SIGTERM proprement
terminer sans corruption
être restartables
ne pas nécessiter un état local caché
```

Configurer les timeouts/grace periods de Gunicorn et Celery de manière cohérente avec Compose.

---

## 21. Admin processes / commandes one-shot

Les tâches administratives ne doivent pas être exécutées en permanence par chaque replica web.

Cible :

```text
migrate
collectstatic
createsuperuser
shell
ensure_demo_periodic_task
```

comme commandes one-shot, par exemple :

```text
docker compose run --rm web python manage.py migrate
```

ou via Ansible avec une exécution unique dans la phase release.

Éviter :

```text
web replica 1 → migrate
web replica 2 → migrate
web replica 3 → migrate
```

---

## 22. Build / Release / Run

Le projet doit formaliser les trois étapes :

```text
BUILD
  → construction image
  → dépendances installées
  → tests build/static

RELEASE
  → image immutable + configuration environnement
  → secrets injectés
  → migrations/collectstatic one-shot

RUN
  → web
  → worker
  → beat
  → nginx
```

Aucun `pip install` ou récupération de code ne doit être effectué au runtime normal.

---

## 23. Dev/Prod parity

Politique :

```text
DEV Lite  = optimisation du feedback développeur
DEV Full  = intégration proche STG
STG       = presque identique à PROD
PROD      = environnement réel
```

SQLite en DEV Lite constitue une exception assumée de confort local.

La qualification de parité se fait avec DEV Full et surtout STG-like.

---

## 24. 12-Factor App — contrat explicite

| # | Facteur | Implémentation cible |
|---|---|---|
| 1 | Codebase | un repo Git, plusieurs déploiements |
| 2 | Dependencies | requirements bornées + image Docker buildée |
| 3 | Config | variables d'environnement + django-environ + Vault |
| 4 | Backing services | PostgreSQL/Redis via URLs externes au code |
| 5 | Build/Release/Run | image immutable, release configurée, runtime séparé |
| 6 | Processes | web/worker/beat séparés, stateless autant que possible |
| 7 | Port binding | Gunicorn bind `0.0.0.0:8000`, Nginx frontal |
| 8 | Concurrency | process types séparés, possibilité de scale web/worker |
| 9 | Disposability | SIGTERM, restart, healthchecks, fail-fast |
| 10 | Dev/prod parity | même image et Compose, STG proche PROD |
| 11 | Logs | stdout/stderr |
| 12 | Admin processes | migrations et commandes Django en one-shot |

Un jalon n'est considéré conforme que lorsque le contrat correspondant est **implémenté et testé**.

---

## 25. Ansible multi-environnement

Structure cible :

```text
ansible-project/
└── inventories/
    ├── dev/
    │   ├── hosts.yml
    │   └── group_vars/
    │       └── all.yml
    ├── stg/
    │   ├── hosts.yml
    │   └── group_vars/
    │       ├── all.yml
    │       └── vault.yml
    └── prod/
        ├── hosts.yml
        └── group_vars/
            ├── all.yml
            └── vault.yml
```

Exemple de variables non secrètes :

```yaml
deployment_environment: stg
django_settings_module: config.settings.stg
compose_files:
  - compose.yml
  - compose.stg.yml
```

Les Vaults STG et PROD sont distincts.

Interdiction de partager volontairement :

```text
DJANGO_SECRET_KEY
POSTGRES_PASSWORD
REDIS_PASSWORD
```

entre staging et production.

---

## 26. Rôles Ansible cibles

Les rôles actifs deviennent :

```text
roles/
├── common/
├── docker_engine/
└── compose_stack/
```

Les rôles historiques natifs :

```text
postgresql
redis
django_app
celery
celery_beat
nginx
```

restent comme référence de migration dans la copie, mais **ne doivent pas être actifs dans le `site.yml` Compose final**.

### 26.1 `docker_engine`

Responsabilités :

```text
installer Docker Engine
installer Compose v2
activer/démarrer Docker
valider docker info
valider docker compose version
```

### 26.2 `compose_stack`

Responsabilités :

```text
créer le répertoire de déploiement
copier/render les fichiers Compose
copier/render Nginx config
déployer l'application ou référencer l'image immutable
rendre le runtime env de manière restrictive
exécuter les admin/release commands
converger avec community.docker.docker_compose_v2
attendre les healthchecks
valider les services
```

---

## 27. Secrets

Sources :

```text
DEV local       → valeurs locales non versionnées
CI              → secrets éphémères générés pour la qualification
STG             → Ansible Vault STG
PROD            → Ansible Vault PROD
```

Aucun secret réel dans :

```text
Git
Dockerfile
compose*.yml
.env.*.example
logs
artifacts publics
README
```

Les tâches Ansible manipulant les secrets doivent utiliser `no_log: true` lorsque nécessaire.

Les fichiers runtime générés doivent avoir des permissions restrictives et être exclus du packaging public.

---

## 28. Fail-fast configuration

Les secrets/valeurs critiques ne doivent pas recevoir de valeurs par défaut faibles.

Exemple attendu :

```text
DJANGO_SECRET_KEY absente en STG/PROD → FAIL
DATABASE_URL absente en STG/PROD     → FAIL
DATABASE_URL SQLite en STG/PROD       → FAIL
CELERY_BROKER_URL absente             → FAIL pour stack async
CELERY_RESULT_BACKEND absente         → FAIL pour stack async
```

Le projet doit préférer un démarrage impossible à un démarrage insecure ou incohérent.

---

## 29. Tests unitaires de configuration

Créer des tests dédiés au contrat settings/base de données.

Matrice minimale :

| Settings | DATABASE_URL | Résultat |
|---|---|---|
| dev | absente | SQLite autorisé |
| dev | PostgreSQL | PostgreSQL |
| dev | SQLite explicite | erreur |
| stg | absente | erreur |
| stg | SQLite | erreur |
| stg | PostgreSQL | OK |
| prod | absente | erreur |
| prod | SQLite | erreur |
| prod | PostgreSQL | OK |

Ajouter aussi :

```text
APPLICATION_ENV invalid → erreur
DJANGO_SETTINGS_MODULE cohérent avec l'environnement
secrets critiques absents → fail-fast
```

---

## 30. Static gate

Le static gate doit contrôler au minimum :

```text
présence django-environ
présence DRF
structure settings/base/dev/stg/prod/database
interdiction SQLite en stg/prod
absence de fallback try/except PostgreSQL→SQLite
Dockerfile non-root
absence de secrets Dockerfile/Compose
compose base + overlays dev/stg/prod
6 services attendus
web/worker/beat même image
aucun port 8000/5432/6379 publié en stg/prod
Redis auth
worker != beat
DatabaseScheduler
logging stdout/stderr
inventories dev/stg/prod
Vault séparés
site.yml n'appelle pas les anciens rôles natifs
syntax-check Ansible
compose config validation
```

---

## 31. Qualification E2E DEV Full

Le scénario DEV Full doit prouver :

```text
Docker daemon actif
Compose v2 disponible
6 services attendus
PostgreSQL healthy
Redis PING authentifié
Django/DRF accessible via Nginx
health database OK
health redis OK
health celery OK
add(21,21) → 42
uppercase("datascientest") → "DATASCIENTEST"
database_probe() → SELECT 1
Beat déclenche la periodic heartbeat
80 publié
8000 non publié
5432 non publié
6379 non publié
```

La requête HTTP canonique doit passer par Nginx.

---

## 32. Qualification STG-like

Une seconde qualification doit lancer la stack avec :

```text
DJANGO_SETTINGS_MODULE=config.settings.stg
DEBUG=false
PostgreSQL obligatoire
SQLite interdit
pas de bind mount code
pas de ports internes publiés
```

Tests négatifs obligatoires :

```text
STG sans DATABASE_URL → échec attendu
STG avec SQLite URL   → échec attendu
```

Cette qualification est le principal test de parité avant PROD.

---

## 33. Idempotence

Deux niveaux :

```text
Ansible site.yml #2 → changed=0
Compose convergence → pas de recréation inutile sans changement
```

Un changement ciblé :

```text
image digest
compose config
environment release
```

doit provoquer uniquement la recréation nécessaire.

---

## 34. GitHub Actions et promotion

Workflow dédié :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose.yml
```

Pipeline cible :

```text
unit tests
  ↓
settings/database policy tests
  ↓
static gate
  ↓
build image once
  ↓
record image digest
  ↓
DEV Full Compose qualification
  ↓
STG-like qualification with same image digest
  ↓
network contract
  ↓
strict idempotence
  ↓
package safety
  ↓
ZIP + SHA-256
  ↓
GitHub Actions artifact
```

Le workflow ne doit pas prétendre à une qualification PROD réelle s'il utilise uniquement un environnement CI containerisé.

---

## 35. Packaging

Le package final doit inclure :

```text
django-app/
docker/
ansible-project/
documentation
static tests
E2E harness
```

et exclure :

```text
.env réels
vault.yml réel
vault password file
private keys
runtime generated secrets
SQLite local db.sqlite3
logs contenant des secrets
images Docker exportées inutilement
```

Produire :

```text
<project>.zip
<project>.zip.sha256
```

avec package safety check.

---

## 36. Roadmap canonique

```text
DC-00  Controlled baseline copy                                  ✅
DC-01  Docker/Compose architecture contracts                      ✅ DESIGN

DC-02  Django configuration foundation
       ├── django-environ
       ├── settings package base/dev/stg/prod/database
       ├── DATABASE_URL policy
       ├── SQLite DEV-only fallback
       ├── PostgreSQL STG/PROD enforcement
       └── APPLICATION_ENV/VERSION/COMMIT                         ⏳ NEXT

DC-03  Django REST Framework
       ├── dependency
       ├── INSTALLED_APPS
       ├── serializers
       ├── task API migration
       └── DRF tests                                               ⏳

DC-04  12-Factor Docker image
       ├── Dockerfile
       ├── .dockerignore
       ├── non-root runtime
       ├── stdout/stderr
       ├── graceful shutdown
       └── immutable artifact contract                             ⏳

DC-05  Base Docker Compose stack
       ├── nginx
       ├── web
       ├── db
       ├── redis
       ├── worker
       └── beat                                                    ⏳

DC-06  Multi-environment Compose
       ├── compose.dev.yml
       ├── compose.stg.yml
       ├── compose.prod.yml
       ├── DEV Lite / DEV Full policy
       └── STG≈PROD contract                                       ⏳

DC-07  Ansible docker_engine                                      ⏳

DC-08  Ansible compose_stack + inventories dev/stg/prod
       ├── inventory contracts
       ├── environment selection
       ├── release commands
       └── Vault separation                                        ⏳

DC-09  Secure runtime configuration
       ├── runtime env rendering
       ├── URL encoding secrets
       ├── fail-fast
       └── package exclusions                                      ⏳

DC-10  Runtime hardening
       ├── healthchecks
       ├── persistence
       ├── network isolation
       ├── logging
       ├── disposability
       └── admin one-off processes                                 ⏳

DC-11  Unit tests + static gate + Compose validation               ⏳

DC-12  DEV Full E2E qualification                                 ⏳

DC-13  STG-like E2E qualification + anti-SQLite negative tests     ⏳

DC-14  Strict Ansible/Compose idempotence                          ⏳

DC-15  Qualified package + SHA-256 + GitHub Actions artifact       ⏳

DC-16  Final qualification report + 12-Factor compliance matrix    ⏳
```

---

## 37. Definition of Done finale

Le projet n'est terminé que si :

```text
[ ] Django utilise django-environ
[ ] settings base/dev/stg/prod/database sont séparés
[ ] DEV sans DATABASE_URL utilise SQLite
[ ] DEV avec DATABASE_URL exige PostgreSQL
[ ] STG sans DATABASE_URL échoue
[ ] STG avec SQLite échoue
[ ] PROD sans DATABASE_URL échoue
[ ] PROD avec SQLite échoue
[ ] DRF sert réellement l'API de tâches
[ ] image Docker non-root
[ ] web/worker/beat réutilisent exactement la même image
[ ] build/release/run sont séparés
[ ] même image digest qualifiée en DEV Full et STG-like
[ ] PostgreSQL et Redis sont des backing services
[ ] Redis est authentifié
[ ] seul Nginx publie le trafic applicatif
[ ] ports 8000/5432/6379 non publiés en STG/PROD
[ ] logs applicatifs vers stdout/stderr
[ ] migrations/admin commands exécutées en one-shot
[ ] Worker et Beat sont séparés
[ ] Beat DatabaseScheduler est fonctionnel
[ ] tâches Celery sont prouvées E2E
[ ] réseau est prouvé E2E
[ ] Ansible changed=0 au second passage
[ ] Compose ne recrée pas inutilement les services
[ ] aucun secret dans le package
[ ] ZIP + SHA-256 produits
[ ] artifact GitHub Actions produit
[ ] matrice 12-Factor finale remplie avec preuves
```

---

## 38. Limites de la future preuve CI

Même avec toutes les qualifications GREEN de cette roadmap, la preuve CI ne couvrira pas automatiquement :

```text
SSH réel vers VPS public
DNS
TLS / Let's Encrypt
UFW / cloud firewall
registry privé réel
backup/restore PostgreSQL production
backup/restore Redis si persistence
rolling update multi-host
haute disponibilité
multi-node Docker/Swarm/Kubernetes
observability backend de production
```

Ces éléments constituent une phase **PROD-LIKE / production hardening** ultérieure.

---

## 39. Décision architecturale résumée

```text
Code                    → Git
Dependencies            → Docker image
Configuration parser    → django-environ
Settings behavior       → base/dev/stg/prod
Local lightweight DB    → SQLite DEV only
Integration/STG/PROD DB → PostgreSQL
Async broker/backend    → Redis authentifié
API                     → Django REST Framework
Web runtime             → Gunicorn
Async runtime           → Celery Worker
Scheduler               → Celery Beat + DatabaseScheduler
Reverse proxy           → Nginx
Container topology      → Docker Compose
Host convergence        → Ansible
Secrets                 → Ansible Vault
Logs                    → stdout/stderr
Release artifact        → immutable image digest
Admin tasks             → one-off processes
```

La règle de sécurité principale reste :

> **SQLite est un confort de développement, jamais un mécanisme de secours opérationnel. En staging et en production, PostgreSQL est obligatoire et toute configuration absente ou invalide doit faire échouer le démarrage.**
