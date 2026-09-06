# LOT 02 — Validation du rôle `common`

## Objectif

Le LOT 02 fournit le socle Linux partagé par `app1` et `db1`, sans introduire de dépendance applicative.

## Livrables

```text
ansible-project/roles/common/
├── README.md
├── defaults/main.yml
├── meta/main.yml
└── tasks/main.yml
```

## Contrôles implémentés

Le rôle :

1. refuse explicitement une plateforme non Ubuntu ou antérieure à 24.04 ;
2. met à jour le cache APT avec `cache_valid_time` ;
3. installe une liste de paquets communs paramétrable ;
4. valide l'existence du timezone demandé ;
5. configure `/etc/localtime` et `/etc/timezone` avec des modules idempotents.

## Paquets communs

```text
ca-certificates
curl
git
lsof
netcat-openbsd
procps
python3
python3-apt
tzdata
```

Ces paquets constituent le socle général et les outils de diagnostic. Les dépendances spécifiques à PostgreSQL seront installées dans le rôle `postgresql`, et celles du runtime Django dans `django_app`.

## Validation runtime attendue

Une fois un inventaire réel disponible :

```bash
ansible all -m ansible.builtin.ping
ansible all -b -m ansible.builtin.include_role -a name=common
```

Dans le playbook d'orchestration final, `common` sera exécuté sur `hosts: all` avant les rôles spécialisés.

Le LOT 02 est considéré **implémenté** à ce stade. Sa preuve d'idempotence réelle sera produite avec les cibles du scénario E2E ; aucun succès runtime n'est prétendu dans ce document.
