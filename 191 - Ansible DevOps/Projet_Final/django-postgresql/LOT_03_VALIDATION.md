# LOT 03 — Validation du rôle `postgresql`

## Objectif

Le LOT 03 implémente le tier PostgreSQL du projet Django/PostgreSQL.

Le rôle est considéré **implémenté**, mais pas encore **qualifié E2E** : les preuves runtime seront produites lorsque `db1` et `app1` seront exécutés dans le scénario complet.

## Livrables

```text
ansible-project/roles/postgresql/
├── README.md
├── defaults/main.yml
├── handlers/main.yml
├── meta/main.yml
├── tasks/main.yml
└── templates/
    └── 99-datascientest.conf.j2
```

## Flux implémenté

```text
Ubuntu 24.04
    ↓
APT packages
    ↓
PostgreSQL service
    ↓
conf.d configuration
    ↓
listen_addresses + :5432
    ↓
SCRAM-SHA-256
    ↓
pg_hba app-only rule
    ↓
role django_app
    ↓
database django_app
    ↓
SELECT 1
```

## Contrôles de sécurité

Le lot introduit les choix suivants :

- aucun login distant `postgres` n'est créé ;
- l'application dispose de son propre rôle PostgreSQL ;
- le rôle applicatif n'est ni superuser, ni créateur de DB, ni créateur de rôles ;
- le mot de passe provient d'Ansible Vault ;
- la tâche qui manipule le mot de passe est protégée avec `no_log: true` ;
- l'authentification distante est configurée en `scram-sha-256` ;
- `pg_hba.conf` n'autorise que le couple base/utilisateur applicatif depuis les CIDR déclarés.

## Variables attendues

Variables publiques :

```yaml
postgresql_database: django_app
postgresql_user: django_app
postgresql_port: 5432
postgresql_app_cidr: <APP1_IP>/32
```

Variable sensible :

```yaml
vault_postgresql_password: <SECRET>
```

Dans Git, seule la forme d'exemple doit être présente.

## Qualification runtime prévue

Le scénario complet devra confirmer :

```text
DB-01 PostgreSQL service active                ⏳
DB-02 PostgreSQL listening on 5432             ⏳
DB-03 django_app role exists                   ⏳
DB-04 django_app database exists               ⏳
DB-05 local SELECT 1 succeeds                  ⏳
DB-06 app1 → db1:5432 succeeds                 ⏳
DB-07 django_app password authentication       ⏳
DB-08 Django migration through this account    ⏳
DB-09 second Ansible run changed=0             ⏳
```

Ces lignes resteront en attente jusqu'à une exécution réelle.

## Critères LOT 03

```text
PostgreSQL installation automatisée            ✅ code
PostgreSQL service managed                      ✅ code
configuration réseau paramétrable               ✅ code
SCRAM-SHA-256                                   ✅ code
pg_hba limité au tier app                       ✅ code
compte applicatif least-privilege               ✅ code
base possédée par le compte applicatif          ✅ code
secret depuis Vault                             ✅ code
handlers restart/reload                         ✅ code
health query locale                             ✅ code
preuve runtime                                  ⏳
preuve idempotence                              ⏳
```

## Conclusion

Le chemin critique côté données est désormais défini :

```text
Django
   ↓ credentials Vault
postgresql_user = django_app
   ↓
TCP :5432
   ↓
PostgreSQL
   ↓
django_app database
```

Le prochain lot peut donc construire le runtime applicatif qui consommera réellement ce contrat : **LOT 04 — rôle `django_app`**.
