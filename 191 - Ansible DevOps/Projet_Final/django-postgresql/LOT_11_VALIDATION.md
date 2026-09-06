# LOT 11 — Idempotence stricte du déploiement

## Objectif

Le LOT 10 a prouvé que la pile complète peut être déployée et validée sur deux cibles Ubuntu 24.04 isolées. Le LOT 11 ajoute le critère Ansible central : **un deuxième `site.yml`, appliqué aux mêmes cibles avec les mêmes variables et les mêmes secrets, ne doit produire aucun changement résiduel**.

Le contrat est strict :

```text
app1 : changed=0
db1  : changed=0
```

Une simple réussite du playbook ne suffit donc pas. Le harness extrait le `PLAY RECAP`, récupère le compteur `changed` de chaque cible et fait échouer la qualification dès qu'une valeur est différente de zéro.

## Scénario

```text
provision app1 + db1
        ↓
first site.yml
        ↓
runtime validation
        ↓
HTTP validation
        ↓
second site.yml
        ↓
assert app1 changed=0
assert db1  changed=0
        ↓
runtime validation post-idempotence
```

Le second passage utilise exactement l'inventaire, le Vault chiffré, les adresses réseau et les deux cibles du premier passage. Aucun reprovisionnement n'est effectué entre les deux exécutions.

## Preuves produites

Le harness écrit notamment :

```text
evidence/validation/idempotence-<timestamp>.txt
```

Ce fichier contient la deuxième exécution complète de `site.yml` et son `PLAY RECAP`. Les validations runtime sont ensuite rejouées afin de vérifier que l'absence de changements n'a pas masqué une régression de service.

## Critères

| ID | Contrôle | Condition de réussite |
|---|---|---|
| IDEMP-01 | deuxième `site.yml` | exit code 0 |
| IDEMP-02 | app1 | `changed=0` |
| IDEMP-03 | db1 | `changed=0` |
| IDEMP-04 | failures | `failed=0` |
| IDEMP-05 | unreachable | `unreachable=0` |
| IDEMP-06 | validation post-run | services et endpoints toujours GREEN |

## Statut

Le gate est implémenté dans le harness E2E via `E2E_CHECK_IDEMPOTENCE=1`. Ce document ne déclare le LOT 11 **GREEN** qu'après observation d'une exécution GitHub Actions réelle satisfaisant les deux compteurs `changed=0`.
