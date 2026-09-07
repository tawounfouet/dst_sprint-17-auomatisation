# Role `common`

Socle système commun aux hôtes `app1` et `db1`.

## Responsabilités

- valider que la cible est Ubuntu 24.04+ ;
- actualiser le cache APT ;
- installer les outils système communs ;
- configurer le fuseau horaire de manière idempotente.

Le rôle ne contient volontairement aucune logique Django, Gunicorn, Nginx ou PostgreSQL.

## Variables

```yaml
common_apt_cache_valid_time: 3600
common_timezone: Europe/Paris
common_manage_timezone: true
common_packages:
  - ca-certificates
  - curl
  - git
  - lsof
  - netcat-openbsd
  - procps
  - python3
  - python3-apt
  - tzdata
```

`common_packages` peut être surchargé dans l'inventaire si l'environnement cible exige d'autres outils de diagnostic.

## Idempotence attendue

Au premier passage, les paquets et le fuseau peuvent produire des changements. Une seconde exécution sur le même hôte convergé doit laisser les tâches en `ok`.
