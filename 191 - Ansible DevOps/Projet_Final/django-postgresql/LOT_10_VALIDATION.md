# LOT 10 — Première qualification end-to-end

## Objectif

Exécuter pour la première fois la pile complète **Nginx → Gunicorn → Django → PostgreSQL** sur deux cibles Ubuntu 24.04 isolées et produire de vraies preuves d'exécution.

Le scénario suit la matrice définie dans `IMPLEMENTATION_PLAN.md` : inventaire, ping, syntax-check, déploiement PostgreSQL, déploiement Django, Gunicorn, Nginx, connectivité applicative vers PostgreSQL, endpoints HTTP et `SELECT 1` via Django.

## Harness de qualification

Le LOT 10 introduit :

```text
ansible-project/
├── requirements-e2e.yml
└── tests/e2e/
    └── run_first_qualification.sh
```

Le script construit deux cibles systemd Ubuntu 24.04 dans Docker :

```text
controller
   ├── community.docker.docker ──► app1
   │                               ├── Nginx :80
   │                               ├── Gunicorn 127.0.0.1:8000
   │                               └── Django
   │                                      │
   │                                      ▼
   └── community.docker.docker ──► db1 ─ PostgreSQL :5432
```

Les secrets PostgreSQL, Django et Vault sont générés de manière éphémère, puis `vault.yml` est chiffré avant le déploiement. Les fichiers runtime sont supprimés à la fin du scénario.

## Sécurité

Le harness refuse de démarrer si un inventaire réel, un Vault réel ou `.vault_pass` existe déjà dans le checkout. Il est destiné à un checkout de qualification jetable et ne doit jamais écraser une configuration de production.

PostgreSQL reste limité au CIDR `/32` réel de la cible `app1`; aucun `trust`, `0.0.0.0/0` ou secret commité n'est introduit.

## Matrice

| ID | Contrôle | Preuve attendue |
|---|---|---|
| E2E-01 | Inventory | graphe Ansible |
| E2E-02 | Ping app1 | PASS |
| E2E-03 | Ping db1 | PASS |
| E2E-04 | Syntax check | PASS |
| E2E-05 | PostgreSQL service | active |
| E2E-06 | PostgreSQL 5432 | listener actif |
| E2E-07 | DB + user | présents |
| E2E-08 | app1 → db1:5432 | connexion TCP |
| E2E-09 | migrations Django | déploiement sans erreur |
| E2E-10 | Gunicorn | active |
| E2E-11 | Gunicorn local 8000 | listener actif |
| E2E-12 | Nginx | active + `nginx -t` |
| E2E-13 | `/health/` | HTTP 200 |
| E2E-14 | `/health/database/` | HTTP 200 |
| E2E-15 | SQL via Django | payload `query: 1` |

## Statut

Le harness est une infrastructure d'exécution du LOT 10. Le LOT n'est déclaré **GREEN** qu'après observation d'une exécution réelle réussie. L'idempotence stricte `changed=0` reste volontairement hors de ce lot et appartient au LOT 11.
