# Architecture — Django + PostgreSQL

```text
                         ANSIBLE CONTROL NODE
                                │ SSH
                  ┌─────────────┴─────────────┐
                  ▼                           ▼
        ┌────────────────────┐      ┌────────────────────┐
        │ app1               │      │ db1                │
        │ Ubuntu 24.04       │      │ Ubuntu 24.04       │
        │ Nginx :80          │      │ PostgreSQL :5432   │
        │ Gunicorn :8000     │─────►│ DB django_app      │
        │ Django             │ SQL  │ user django_app    │
        └────────────────────┘      └────────────────────┘
```

Gunicorn écoute uniquement sur `127.0.0.1:8000`. PostgreSQL est exposé au réseau applicatif mais son `pg_hba.conf` est limité au client `app1` quand une adresse CIDR est fournie.
