# Role `postgresql`

Ce rôle construit le tier base de données du projet Django/PostgreSQL.

## Responsabilités

```text
Install PostgreSQL
        ↓
Start + enable service
        ↓
Load managed conf.d
        ↓
listen_addresses / port / SCRAM
        ↓
pg_hba rule limited to app CIDR
        ↓
Create application role
        ↓
Create application database
        ↓
SELECT 1 local verification
```

## Sécurité

Le rôle n'autorise pas de connexion distante du superutilisateur PostgreSQL. L'application utilise un compte dédié :

```text
database : django_app
role     : django_app
```

Le mot de passe est injecté depuis :

```yaml
vault_postgresql_password: ...
```

et la tâche de création/mise à jour du compte utilise `no_log: true`.

L'accès réseau est limité à :

```yaml
postgresql_allowed_cidrs:
  - "{{ postgresql_app_cidr }}"
```

Dans un environnement où `app1` est adressé par hostname ou par un réseau Docker, cette valeur doit être explicitement surchargée avec un CIDR valide.

## Authentification

Les connexions distantes du compte applicatif utilisent :

```text
scram-sha-256
```

La configuration PostgreSQL est déposée dans :

```text
/etc/postgresql/<version>/main/conf.d/99-datascientest.conf
```

Le rôle conserve le fichier `pg_hba.conf` système et ajoute uniquement la règle nécessaire à l'application via `community.postgresql.postgresql_pg_hba`.

## Dépendances système

```text
acl
postgresql
postgresql-contrib
libpq-dev
python3-psycopg2
```

`python3-psycopg2` permet aux modules `community.postgresql` de piloter l'instance locale.

## Variables principales

```yaml
postgresql_version: "16"
postgresql_cluster_name: main
postgresql_port: 5432
postgresql_listen_addresses: "*"
postgresql_password_encryption: scram-sha-256
postgresql_database: django_app
postgresql_user: django_app
postgresql_password: "{{ vault_postgresql_password }}"
```

Le rôle cible Ubuntu 24.04, pour lequel le projet utilise PostgreSQL 16 comme version de cluster de référence. Cette version reste paramétrable.

## Idempotence attendue

Une seconde exécution sur une cible déjà convergée doit conserver :

```text
packages       ok
configuration  ok
pg_hba         ok
role           ok
database       ok
query          ok
```

La preuve `changed=0` sera produite pendant la qualification E2E et ne doit pas être déduite du seul code du rôle.
