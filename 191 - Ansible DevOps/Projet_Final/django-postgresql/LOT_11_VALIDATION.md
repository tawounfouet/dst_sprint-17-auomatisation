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

| ID | Contrôle | Condition de réussite | Résultat réel |
|---|---|---|---|
| IDEMP-01 | deuxième `site.yml` | exit code 0 | ✅ |
| IDEMP-02 | app1 | `changed=0` | ✅ `ok=34 changed=0 failed=0 unreachable=0` |
| IDEMP-03 | db1 | `changed=0` | ✅ `ok=21 changed=0 failed=0 unreachable=0` |
| IDEMP-04 | failures | `failed=0` | ✅ |
| IDEMP-05 | unreachable | `unreachable=0` | ✅ |
| IDEMP-06 | validation post-run | services et endpoints toujours GREEN | ✅ |

## Qualification réelle GREEN

Run GitHub Actions de référence :

```text
Workflow : Ansible Django PostgreSQL Qualification
Run      : #5
Run ID   : 34051855639
Job ID   : 101536778596
Commit   : ac1b23cd9e604252eca2dafdf2524a5629627350
```

Le premier déploiement de ce run a confirmé le comportement d'installation attendu :

```text
app1      : ok=37 changed=24 unreachable=0 failed=0
db1       : ok=23 changed=13 unreachable=0 failed=0
localhost : ok=1  changed=0  unreachable=0 failed=0
```

La validation runtime intermédiaire est restée non-mutante :

```text
app1      : ok=13 changed=0 unreachable=0 failed=0
db1       : ok=6  changed=0 unreachable=0 failed=0
localhost : ok=1  changed=0 unreachable=0 failed=0
```

Le second `site.yml`, exécuté sur les **mêmes cibles**, a produit :

```text
app1      : ok=34 changed=0 unreachable=0 failed=0 skipped=1
db1       : ok=21 changed=0 unreachable=0 failed=0 skipped=0
localhost : ok=1  changed=0 unreachable=0 failed=0 skipped=0
```

Le harness a ensuite émis explicitement :

```text
IDEMPOTENCE PASS: app1 changed=0
IDEMPOTENCE PASS: db1 changed=0
LOT 11 strict idempotence qualification passed.
```

Enfin, une nouvelle validation runtime après ce second passage a confirmé :

```text
app1      : ok=13 changed=0 unreachable=0 failed=0
db1       : ok=6  changed=0 unreachable=0 failed=0
localhost : ok=1  changed=0 unreachable=0 failed=0
```

L'idempotence n'a donc pas été obtenue au prix d'une régression de service.

## Artefact de preuves

```text
Nom       : ansible-django-postgresql-lot11-evidence
Artifact  : 9994826126
Taille    : 6735 octets
SHA-256   : 3026a4a328178302a88305e72ecb7b7054f4e192b47b49969c6fb388c74d8a1c
Expiration: 2026-09-20 18:32:13Z
```

L'artefact contient les logs du premier déploiement, le log du second passage d'idempotence, les validations runtime et les preuves HTTP/service générées par le harness.

## Observations

Aucune correction de rôle n'a été nécessaire pour atteindre `changed=0` : les implémentations `common`, `postgresql`, `django_app` et `nginx` se sont révélées idempotentes sur la qualification réelle.

Le run fait néanmoins apparaître deux avertissements de dépréciation sans impact sur le résultat : l'usage des facts injectés au niveau racine (`ansible_distribution`, etc.) et l'alias `db` dans une validation `community.postgresql`. Ils constituent une dette de compatibilité à nettoyer avant la stabilisation finale, mais ne remettent pas en cause le LOT 11.

## Statut

**LOT 11 : ✅ GREEN — idempotence stricte démontrée réellement.**

La prochaine étape est le **LOT 12 — GitHub Actions E2E final**, qui transformera ce scénario maintenant qualifié en gate CI final du projet, avec packaging, SHA-256 et artefact complet prêt pour le rapport de qualification.
