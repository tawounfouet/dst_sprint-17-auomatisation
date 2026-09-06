# LOT 12 — Pipeline GitHub Actions E2E final

## Objectif

Transformer les qualifications GREEN des LOT 10 et LOT 11 en une barrière CI finale reproductible.

Le pipeline final doit prouver, dans un seul run GitHub Actions :

```text
static gate
   ↓
provision app1 + db1 Ubuntu 24.04
   ↓
first site.yml
   ↓
runtime validation + HTTP
   ↓
second site.yml
   ↓
app1 changed=0 / db1 changed=0
   ↓
runtime validation post-idempotence
   ↓
package projet
   ↓
SHA-256 verify
   ↓
package safety gate
   ↓
artifact final
```

## Gates

| ID | Contrôle | Condition |
|---|---|---|
| CI-01 | static checks | PASS |
| CI-02 | premier déploiement | `failed=0`, `unreachable=0` |
| CI-03 | runtime | PostgreSQL, Gunicorn et Nginx actifs |
| CI-04 | HTTP | `/`, `/health/`, `/health/database/`, `/api/info/` GREEN |
| CI-05 | SQL applicatif | `query=1` via Django |
| CI-06 | deuxième déploiement | exit code 0 |
| CI-07 | idempotence app1 | `changed=0` |
| CI-08 | idempotence db1 | `changed=0` |
| CI-09 | packaging | ZIP produit |
| CI-10 | intégrité | `sha256sum -c` PASS |
| CI-11 | sécurité artefact | aucun Vault réel, inventaire réel, clé ou `.vault_pass` |
| CI-12 | artefact final | upload GitHub Actions réussi |

## Hardening inclus

Le LOT 12 supprime également les avertissements de compatibilité déjà observés pendant LOT 10/11 :

- utilisation de `ansible_facts[...]` au lieu des facts injectés historiques ;
- utilisation de `login_db` au lieu de l'alias PostgreSQL `db` déprécié.

Ces changements sont requalifiés par le pipeline complet : ils ne sont pas considérés valides sans run GREEN.

## Packaging

`scripts/package.sh` accepte `PACKAGE_OUTPUT_DIR` pour permettre à la CI de produire le ZIP dans un répertoire éphémère contrôlé. Les fichiers `*.example.yml` restent inclus, tandis que les fichiers runtime réels restent exclus.

`tests/package_safety_check.sh` inspecte ensuite le contenu du ZIP et vérifie la présence des composants attendus ainsi que l'absence des fichiers sensibles.

## Statut

Le LOT 12 est **implémenté** lorsque le workflow et les gates existent. Il n'est déclaré **GREEN** qu'après observation d'un run GitHub Actions final réussi, incluant le ZIP, le SHA-256 vérifié et l'artefact final.
