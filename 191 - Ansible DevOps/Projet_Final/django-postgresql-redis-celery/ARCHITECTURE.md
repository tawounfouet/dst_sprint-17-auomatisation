# Architecture — Django + PostgreSQL + Redis + Celery

## 1. Décision d'architecture

La variante `django-postgresql-redis-celery` cible en priorité une **topologie mono-serveur Ubuntu 24.04**.

Le même hôte Ansible `server1` héberge :

- Nginx ;
- Gunicorn ;
- Django ;
- PostgreSQL ;
- Redis ;
- un worker Celery.

Cette décision est volontaire : elle correspond à la future cible VPS du projet tout en conservant des frontières de services propres et des rôles Ansible séparés.

## 2. Architecture cible

```text
                    ANSIBLE CONTROL NODE
                           │
                           │ Ansible
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ server1 — Ubuntu 24.04 + systemd                            │
│                                                             │
│ Client / runner                                             │
│       │                                                     │
│       │ HTTP :80                                            │
│       ▼                                                     │
│   ┌─────────┐                                               │
│   │  Nginx  │                                               │
│   └────┬────┘                                               │
│        │ proxy_pass                                         │
│        ▼                                                     │
│   Gunicorn 127.0.0.1:8000                                  │
│        │                                                     │
│        ▼                                                     │
│      Django                                                  │
│        │                           │                         │
│        │ SQL                       │ publish / read result   │
│        ▼                           ▼                         │
│ PostgreSQL                    Redis                          │
│ 127.0.0.1:5432               127.0.0.1:6379                │
│                                    │                        │
│                                    │ broker                 │
│                                    ▼                        │
│                              Celery Worker                  │
│                                    │                        │
│                                    ├── add(x, y)            │
│                                    ├── uppercase(value)     │
│                                    └── database_probe()     │
│                                             │               │
│                                             ▼               │
│                                        PostgreSQL           │
└─────────────────────────────────────────────────────────────┘
```

## 3. Contrat réseau

Le contrat réseau mono-host est strict :

```text
Port   Service       Bind attendu       Accessible hors host
----   ------------  -----------------  --------------------
80     Nginx         0.0.0.0 / ::       OUI
8000   Gunicorn      127.0.0.1          NON
5432   PostgreSQL    127.0.0.1          NON
6379   Redis         127.0.0.1          NON
```

La qualification CI devra échouer si `8000`, `5432` ou `6379` devient joignable depuis le namespace réseau du runner.

Pour une future VPS publique, le contrat sera étendu à `443` pour HTTPS et `80` pourra rediriger vers `443`. Redis, PostgreSQL et Gunicorn resteront localhost-only.

## 4. Responsabilités des composants

### Nginx

Point d'entrée HTTP. Nginx est le seul service applicatif exposé par le scénario CI initial.

```text
Client → Nginx :80 → Gunicorn 127.0.0.1:8000
```

### Gunicorn

Serveur WSGI de Django. Il reste strictement local à la machine :

```text
127.0.0.1:8000
```

### Django

Django porte :

- les endpoints existants de santé ;
- les nouveaux endpoints Redis/Celery ;
- la soumission des tâches ;
- la lecture de leur état/résultat.

### PostgreSQL

Base relationnelle de l'application. En mono-host :

```text
listen_addresses = '127.0.0.1'
port = 5432
```

L'utilisateur applicatif reste un compte dédié avec privilèges minimaux.

### Redis

Redis joue deux rôles :

```text
DB logique /0 → broker Celery
DB logique /1 → result backend Celery
```

Contrat de sécurité :

```text
bind 127.0.0.1
protected-mode yes
port 6379
authentification activée
```

Le mot de passe provient d'Ansible Vault et ne doit jamais apparaître dans les logs ou le dépôt.

### Celery Worker

Le worker consomme les messages du broker Redis et exécute les tâches Django.

Le service systemd cible est :

```text
datascientest-celery.service
```

Le worker utilise le même code Django, le même `.venv` et le même fichier d'environnement que Gunicorn afin d'éviter deux runtimes Python divergents.

## 5. Modèle de déploiement Ansible

Six rôles seront utilisés :

```text
roles/
├── common/
├── postgresql/
├── redis/
├── django_app/
├── celery/
└── nginx/
```

Ordre d'orchestration :

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
nginx
```

Les dépendances sont ainsi disponibles avant leurs consommateurs : PostgreSQL et Redis avant Django/Celery, puis Gunicorn/Celery avant la validation Nginx et runtime.

## 6. Contrat de configuration Redis/Celery

Les secrets ne sont pas codés dans Django.

Le Vault de la variante doit contenir au minimum :

```yaml
vault_postgresql_password: ...
vault_django_secret_key: ...
vault_redis_password: ...
```

Les URLs Celery seront injectées dans l'environnement du runtime :

```text
CELERY_BROKER_URL       → redis://:<secret>@127.0.0.1:6379/0
CELERY_RESULT_BACKEND   → redis://:<secret>@127.0.0.1:6379/1
```

L'implémentation devra encoder correctement le secret Redis pour une URL et utiliser `no_log: true` sur les tâches Ansible qui le manipulent.

Contrats Celery initiaux :

```text
task serializer   = json
result serializer = json
accepted content  = json
timezone          = Europe/Paris
UTC               = enabled
```

Aucun Celery Beat n'est prévu dans cette première variante.

## 7. Contrat des tâches de démonstration

### `add(x, y)`

Entrée : deux nombres.

```text
add(21, 21) → 42
```

Cette tâche prouve le round-trip Django → Redis → Celery → Redis → Django.

### `uppercase(value)`

Entrée : chaîne de caractères.

```text
uppercase("datascientest") → "DATASCIENTEST"
```

Elle vérifie notamment la sérialisation JSON des arguments et résultats.

### `database_probe()`

Le worker charge le contexte Django puis effectue une vraie requête vers PostgreSQL :

```text
Celery
  ↓
Django DB connection
  ↓
psycopg
  ↓
PostgreSQL
  ↓
SELECT 1
```

Résultat attendu : valeur `1` ou payload explicitement équivalent à un état healthy.

## 8. Contrat HTTP/API

Les endpoints existants restent disponibles :

```text
GET /
GET /health/
GET /health/database/
GET /api/info/
```

Les nouveaux endpoints cibles sont :

```text
GET  /health/redis/
GET  /health/celery/
POST /api/tasks/add/
POST /api/tasks/uppercase/
POST /api/tasks/database-probe/
GET  /api/tasks/<task_id>/
```

### Santé Redis

`GET /health/redis/` doit exécuter un vrai `PING` authentifié et retourner une erreur si Redis est indisponible.

### Santé Celery

`GET /health/celery/` doit vérifier qu'au moins un worker répond. Le simple statut systemd n'est pas considéré comme une preuve fonctionnelle suffisante.

### Soumission asynchrone

Une soumission valide retourne un identifiant de tâche sans attendre l'exécution complète :

```json
{
  "task_id": "...",
  "status": "PENDING"
}
```

Le endpoint de lecture retourne ensuite l'état Celery et, en cas de succès, le résultat sérialisable JSON.

## 9. Contrat systemd

Services attendus :

```text
postgresql.service          active
gunicorn / datascientest-django.service active
redis-server.service        active
datascientest-celery.service active
nginx.service               active
```

Le service Celery doit :

- tourner sous l'utilisateur système Django ;
- utiliser `/opt/datascientest-django` comme `WorkingDirectory` ;
- charger le fichier d'environnement Django ;
- utiliser le binaire Celery du `.venv` ;
- être activé au boot ;
- redémarrer uniquement lorsque sa configuration ou le code pertinent change.

## 10. Contrat de validation E2E

La future qualification GitHub Actions devra prouver dans l'ordre :

```text
static checks
    ↓
server1 Ubuntu 24.04 + systemd
    ↓
site.yml #1
    ↓
5 services actifs
    ↓
HTTP Django healthy
    ↓
PostgreSQL SELECT 1
    ↓
Redis PING/PONG
    ↓
Celery worker répond
    ↓
add(21,21) = 42
    ↓
uppercase("datascientest") = "DATASCIENTEST"
    ↓
database_probe() = SELECT 1
    ↓
80 reachable
8000/5432/6379 non joignables hors host
    ↓
site.yml #2
    ↓
server1 changed=0
    ↓
validation runtime post-idempotence
    ↓
ZIP + SHA-256 + package safety + artifact
```

## 11. Frontières de qualification

Avant son propre run E2E GREEN, cette variante ne doit pas être décrite comme qualifiée.

La future preuve GitHub Actions restera une qualification **CI/container mono-host**. Elle ne prouvera pas encore :

- SSH vers une VPS publique réelle ;
- firewall fournisseur/VPS ;
- DNS public ;
- TLS/Let's Encrypt ;
- persistance après incident de la VPS ;
- backup/restore PostgreSQL externe ;
- haute disponibilité Redis/Celery.

Ces sujets restent hors du périmètre de la première variante Redis/Celery.
