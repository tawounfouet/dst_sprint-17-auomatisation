# Guide d'implémentation

Le point d'entrée du déploiement est :

```text
ansible-project/playbooks/site.yml
```

L'orchestration applique successivement `common`, `postgresql`, `django_app`, puis `nginx`. Les secrets `vault_postgresql_password` et `vault_django_secret_key` résident dans `inventories/prod/group_vars/vault.yml`, fichier local chiffré et non versionné.

Le runtime Python utilise exclusivement le module standard `venv` avec :

```text
/opt/datascientest-django/.venv
```

## Barrière statique

Avant tout déploiement ou qualification :

```bash
cd ansible-project
./tests/static_checks.sh
```

Cette suite contrôle la structure, le scaffold Django, les syntaxes disponibles, plusieurs invariants de hardening et les fichiers sensibles suivis par Git. Elle ne remplace pas la qualification runtime.

## Workflow d'exploitation

```bash
./tests/static_checks.sh
./scripts/preflight.sh
./scripts/deploy.sh
./scripts/validate_runtime.sh
./scripts/package.sh
```

Le flux devient :

```text
static checks
     ↓
preflight
     ↓
deploy
     ↓
runtime validation
     ↓
package + SHA-256
```

Les sorties réelles sont conservées sous `evidence/`. Les logs et packages générés ne doivent jamais exposer de secrets.

`package.sh` exclut notamment Vault réel, `.vault_pass`, inventaire/host vars réels, environnements Python et clés privées.

La qualification finale attend `/health/` et `/health/database/` en HTTP 200 ainsi qu'une seconde exécution de `site.yml` avec `changed=0` sur `app1` et `db1`. Ces résultats ne sont considérés comme acquis qu'après exécution réelle.
