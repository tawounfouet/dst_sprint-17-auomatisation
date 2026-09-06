# LOT 07 — Validation runtime

## Objectif

Le LOT 07 ajoute un playbook dédié à la vérification du système déployé, sans modifier l'état cible.

Le point d'entrée est :

```text
ansible-project/playbooks/validate.yml
```

La validation couvre le tier PostgreSQL, le tier applicatif Django/Gunicorn, Nginx et le chemin Django → PostgreSQL.

---

## Contrôles implémentés

### Tier PostgreSQL

```text
PostgreSQL service active
PostgreSQL 127.0.0.1:5432 accessible
base django_app existante
rôle django_app existant
```

La présence de la base et du rôle est vérifiée en lecture seule via `community.postgresql.postgresql_query`, exécuté sous l'utilisateur système `postgres`. Les paramètres sont transmis avec `named_args` plutôt que concaténés dans la requête SQL.

### Tier application

```text
Gunicorn service active
Gunicorn 127.0.0.1:8000 accessible
Nginx service active
nginx -t valide
Nginx 127.0.0.1:80 accessible
app1 → db1:5432 accessible
```

### Endpoints HTTP

```text
GET /                    → 200
GET /health/             → 200
GET /health/database/    → 200
GET /api/info/           → 200
```

Le payload de `/health/database/` doit confirmer :

```json
{
  "status": "healthy",
  "database": "connected",
  "query": 1
}
```

Cette vérification constitue la preuve fonctionnelle attendue du chemin :

```text
Nginx
  ↓
Gunicorn
  ↓
Django
  ↓
psycopg
  ↓
PostgreSQL
  ↓
SELECT 1
```

---

## Commande de validation

Depuis `ansible-project/` :

```bash
ansible-playbook playbooks/validate.yml
```

Le playbook ne charge pas le Vault : il n'a pas besoin de relire les secrets pour tester le runtime. La validation de l'authentification applicative PostgreSQL est indirectement couverte par `/health/database/`, qui utilise la configuration réelle du service Django.

---

## Matrice LOT 07

| ID | Contrôle | Statut code |
|---|---|---|
| RUN-01 | topologie app/database | ✅ implémenté |
| RUN-02 | PostgreSQL actif | ✅ implémenté |
| RUN-03 | PostgreSQL :5432 | ✅ implémenté |
| RUN-04 | base Django existante | ✅ implémenté |
| RUN-05 | rôle PostgreSQL applicatif existant | ✅ implémenté |
| RUN-06 | Gunicorn actif | ✅ implémenté |
| RUN-07 | Gunicorn :8000 | ✅ implémenté |
| RUN-08 | Nginx actif | ✅ implémenté |
| RUN-09 | `nginx -t` | ✅ implémenté |
| RUN-10 | Nginx :80 | ✅ implémenté |
| RUN-11 | app1 → db1:5432 | ✅ implémenté |
| RUN-12 | GET `/` | ✅ implémenté |
| RUN-13 | GET `/health/` | ✅ implémenté |
| RUN-14 | GET `/health/database/` + `SELECT 1` | ✅ implémenté |
| RUN-15 | GET `/api/info/` | ✅ implémenté |

---

## Preuve runtime

À ce stade, le LOT 07 est **implémenté**, mais les contrôles ci-dessus ne sont pas encore déclarés réussis sur une cible réelle dans ce document.

Les preuves d'exécution seront produites dans les lots suivants, notamment via les scripts d'exploitation, la qualification E2E et GitHub Actions.

Aucun log de succès, compteur Ansible ou résultat HTTP n'est fabriqué ici.
