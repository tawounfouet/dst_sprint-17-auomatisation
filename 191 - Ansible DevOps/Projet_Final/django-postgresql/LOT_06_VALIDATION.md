# LOT 06 — Orchestration `site.yml`

## Objectif

Assembler les quatre rôles implémentés lors des LOT 02 à 05 dans un seul point d'entrée Ansible, en respectant leurs dépendances techniques.

## Ordre d'orchestration

```text
00 — validate topology
        ↓
01 — common       (all)
        ↓
02 — postgresql   (database)
        ↓
03 — django_app   (app)
        ↓
04 — nginx        (app)
```

Cet ordre est essentiel : Django exécute `manage.py migrate`, ce qui nécessite PostgreSQL opérationnel. Nginx vérifie ensuite que Gunicorn écoute déjà sur `127.0.0.1:8000`.

## Contrat d'inventaire

La version actuelle du projet assume :

```text
app      → 1 hôte
 database → 1 hôte
```

Le play initial utilise `ansible.builtin.assert` pour refuser une topologie différente. Cette contrainte pourra être levée dans une version future si l'architecture évolue vers plusieurs nœuds applicatifs ou une base PostgreSQL HA.

## Chargement Vault

Le projet ne se repose pas implicitement sur un fichier arbitraire placé sous `group_vars/`.

Les plays qui consomment des secrets déclarent explicitement :

```yaml
vars_files:
  - ../inventories/prod/group_vars/vault.yml
```

Les secrets minimums sont contrôlés avant l'exécution des rôles :

```text
vault_postgresql_password
vault_django_secret_key
```

Les assertions utilisent `no_log: true` afin de ne pas exposer les valeurs.

## Gestion des erreurs

Les plays distants utilisent :

```yaml
any_errors_fatal: true
```

L'objectif est d'interrompre la chaîne si une étape fondamentale échoue plutôt que de poursuivre vers un tier dépendant dans un état partiellement configuré.

## Tags

```text
common
postgresql / database
django / app
nginx / app
topology
```

Ils permettent un diagnostic ciblé tout en conservant la validation de topologie.

## Matrice de validation

| ID | Contrôle | Statut actuel |
|---|---|---|
| ORCH-01 | `site.yml` présent | ✅ implémenté |
| ORCH-02 | topologie app/database contrôlée | ✅ implémenté |
| ORCH-03 | `common` avant les rôles spécialisés | ✅ implémenté |
| ORCH-04 | PostgreSQL avant Django | ✅ implémenté |
| ORCH-05 | Django avant Nginx | ✅ implémenté |
| ORCH-06 | Vault chargé explicitement | ✅ implémenté |
| ORCH-07 | assertions secrets | ✅ implémenté |
| ORCH-08 | syntax-check réel | ⏳ LOT 08/09 |
| ORCH-09 | premier déploiement complet | ⏳ LOT 10 |
| ORCH-10 | second run `changed=0` | ⏳ LOT 11 |

## Statut

Le LOT 06 est **implémenté**, mais il n'est pas encore qualifié runtime. Les preuves seront ajoutées uniquement après exécution réelle du playbook sur les cibles de qualification.
