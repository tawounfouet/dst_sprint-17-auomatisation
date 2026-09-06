# LOT 10 — Première qualification end-to-end

## Statut

**GREEN — qualification E2E d'intégration réussie le 6 septembre 2026.**

Cette qualification couvre la pile **Nginx → Gunicorn → Django → PostgreSQL** sur deux cibles Ubuntu 24.04 isolées. Le transport de contrôle Ansible est `community.docker.docker` : il s'agit donc d'une qualification d'intégration système réelle dans des cibles Linux séparées, et non d'une qualification SSH/public-cloud/production.

## Exécution de référence

| Élément | Valeur |
|---|---|
| Workflow | `Ansible Django PostgreSQL Qualification` |
| Run | `#3` |
| Run ID | `34049648664` |
| Job | `first-e2e` |
| Job ID | `101530818321` |
| Head qualifié | `f5e47214eeeabfa6c312e604da87801d69918191` |
| Début | `2026-09-06T17:46:33Z` |
| Fin | `2026-09-06T17:49:22Z` |
| Runner | Ubuntu 24.04.4 |
| Python | 3.12.14 |
| ansible-core | 2.20.8 |
| `community.postgresql` | 4.2.0 |
| `community.docker` | 4.8.8 |
| Résultat | `success` |

Run GitHub Actions :

`https://github.com/tawounfouet/dst_sprint-17-auomatisation/actions/runs/34049648664`

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

Lors du run de référence, les cibles ont reçu les adresses éphémères suivantes :

```text
app1 = 172.18.0.2
db1  = 172.18.0.3
```

Ces adresses appartiennent uniquement au réseau Docker jetable de la qualification et ne constituent pas des adresses d'infrastructure à conserver.

## Sécurité

Les secrets PostgreSQL, Django et Vault sont générés de manière éphémère. `vault.yml` est chiffré avant le déploiement, puis l'inventaire runtime, le Vault et `.vault_pass` sont supprimés en fin d'exécution.

Le harness refuse de démarrer si l'un de ces fichiers existe déjà, afin de ne jamais écraser une configuration réelle. PostgreSQL a été configuré avec le CIDR exact de `app1` :

```text
172.18.0.2/32
```

Le scénario n'introduit ni authentification `trust`, ni CIDR large `0.0.0.0/0`, ni secret versionné. Gunicorn reste lié à `127.0.0.1:8000`.

## Static gate et preflight

Avant le déploiement réel, le run a validé :

- structure Ansible ;
- scaffold Django et dépendances ;
- syntaxe Bash ;
- syntaxe Python ;
- syntaxe YAML ;
- `.venv` ;
- SCRAM PostgreSQL ;
- absence de `trust` et de CIDR large ;
- Gunicorn local-only ;
- absence de wildcard `ALLOWED_HOSTS` ;
- absence de fichiers sensibles interdits dans Git ;
- `site.yml --syntax-check` ;
- `validate.yml --syntax-check` ;
- graphe d'inventaire `app1` / `db1` ;
- ping Ansible réussi sur les deux cibles.

## Premier déploiement réel

Le premier `site.yml` s'est terminé sans échec ni hôte injoignable :

```text
app1      : ok=37 changed=24 unreachable=0 failed=0 skipped=0
db1       : ok=23 changed=13 unreachable=0 failed=0 skipped=0
localhost : ok=1  changed=0  unreachable=0 failed=0 skipped=0
```

Le déploiement a notamment observé réellement :

```text
common
  ↓
PostgreSQL install + service
  ↓
pg_hba SCRAM app1/32
  ↓
database + role django_app
  ↓
SELECT 1 local PostgreSQL
  ↓
Django runtime packages
  ↓
system user/group
  ↓
source deployment
  ↓
python3 -m venv
  ↓
pip dependencies
  ↓
runtime env
  ↓
Django check
  ↓
migrations
  ↓
collectstatic
  ↓
Gunicorn systemd
  ↓
Nginx reverse proxy
```

## Validation runtime réelle

`validate.yml` s'est terminé avec `changed=0`, `failed=0` et `unreachable=0` :

```text
app1      : ok=13 changed=0 unreachable=0 failed=0 skipped=0
db1       : ok=6  changed=0 unreachable=0 failed=0 skipped=0
localhost : ok=1  changed=0 unreachable=0 failed=0 skipped=0
```

Les contrôles réussis comprennent :

| ID | Contrôle | Résultat |
|---|---|---|
| E2E-01 | Inventory | ✅ graphe `app1` / `db1` |
| E2E-02 | Ping app1 | ✅ `pong` |
| E2E-03 | Ping db1 | ✅ `pong` |
| E2E-04 | Syntax check | ✅ `site.yml` + `validate.yml` |
| E2E-05 | PostgreSQL service | ✅ actif |
| E2E-06 | PostgreSQL 5432 | ✅ listener actif |
| E2E-07 | DB + user | ✅ présents |
| E2E-08 | app1 → db1:5432 | ✅ connexion TCP |
| E2E-09 | migrations Django | ✅ appliquées sans erreur |
| E2E-10 | Gunicorn | ✅ actif |
| E2E-11 | Gunicorn local 8000 | ✅ listener actif |
| E2E-12 | Nginx | ✅ actif + `nginx -t` |
| E2E-13 | `/health/` | ✅ HTTP 200 |
| E2E-14 | `/health/database/` | ✅ HTTP 200 |
| E2E-15 | SQL via Django | ✅ `database=connected`, `query=1` |

Le contrôle final côté runner a également observé :

```text
app1 nginx=active
app1 gunicorn=active
db1 postgresql=active
```

Les quatre endpoints ont été interrogés depuis le nœud de contrôle et leurs réponses ont été conservées dans l'artefact de preuve.

## Artefact de preuve

| Élément | Valeur |
|---|---|
| Nom | `ansible-django-postgresql-lot10-evidence` |
| Artifact ID | `9994182587` |
| Taille | `4102` octets |
| SHA-256 GitHub | `54dbd8bbece6ac9fa3b103c5dc6af1f838250747a499dd2b82f607b47e3eaca8` |
| Expiration | `2026-09-20T17:49:18Z` |

Téléchargement :

`https://github.com/tawounfouet/dst_sprint-17-auomatisation/actions/runs/34049648664/artifacts/9994182587`

L'artefact contient huit fichiers issus des logs de déploiement et des validations runtime/HTTP.

## Incidents rencontrés avant le GREEN

Deux premières tentatives ont échoué avant le déploiement des cibles, et ont servi à corriger la barrière statique elle-même.

### Run #1 — erreur de quoting Bash

Run ID : `34049497067`.

La construction d'une expression `grep` pour détecter `django_allowed_hosts: "*"` contenait un quoting shell invalide. `bash -n` a correctement bloqué le pipeline. Correction : réécriture de la garde avec deux expressions shell sûres.

### Run #2 — faux positif sur les sentinelles Vault

Run ID : `34049564010`.

La garde `CHANGE_ME_` inspectait aussi `playbooks/site.yml`, alors que ce playbook contient volontairement les chaînes `CHANGE_ME_*` afin de **refuser** un Vault exemple non modifié. Le contrôle a donc signalé sa propre protection comme un problème.

Correction : limiter cette recherche aux contenus réellement déployés (`roles/`, `django-app/config`, `django-app/health`) et conserver les sentinelles de rejet dans le playbook.

## Points techniques observés

Le run est GREEN, mais il expose deux travaux de maintenance non bloquants :

1. `ansible-core 2.20.8` signale la future suppression de l'injection des facts sous forme de variables `ansible_*`; les rôles devront progressivement utiliser `ansible_facts[...]`.
2. `community.postgresql 4.2.0` signale que l'alias `db` utilisé dans une requête de validation sera supprimé en version 5 ; il faudra adopter le nom de paramètre actuel avant de relever la borne de collection.

Ces avertissements n'ont provoqué ni échec ni comportement incorrect pendant la qualification.

## Limite volontaire du LOT 10

Le `changed=0` ci-dessus concerne **le playbook de validation**, qui est conçu pour être non-mutant. Il ne constitue pas encore la preuve d'idempotence de `site.yml`.

La preuve stricte suivante reste donc à produire au LOT 11 :

```text
1er site.yml   → déploiement réel GREEN
2e site.yml    → app1 changed=0
                 db1  changed=0
```

Le LOT 10 est ainsi clôturé **GREEN**, tandis que l'idempotence du déploiement reste explicitement ouverte pour le LOT 11.
