# Examen — Ansible DevOps

Ce dossier formalise l’évaluation finale du module Ansible du Sprint 17.

## Source de vérité

Le document de référence du cours demande d’automatiser le déploiement d’un site e-commerce avec :

```text
Prestashop + MySQL
```

au moyen de deux rôles distincts, en garantissant la communication entre le serveur web et la base de données.

Le support autorise également une alternative telle que Magento ou WordPress, si elle répond au besoin exprimé.

## Documents

| Document | Rôle |
|---|---|
| `191.07_ENONCE_EVALUATION_DATASCIENTEST.md` | transcription structurée de l’énoncé |
| `191.07_ANALYSE_EXIGENCES.md` | exigences fonctionnelles et techniques |
| `191.07_ARCHITECTURE_CIBLE.md` | topologie et flux attendus |
| `191.07_PLAN_IMPLEMENTATION.md` | séquencement de réalisation |
| `191.07_CHECKLIST_VALIDATION.md` | critères de sortie |
| `191.07_STRATEGIE_TESTS.md` | plan de tests et preuves |
| `191.07_CORRIGE_REFERENCE.md` | blueprint de solution de référence |

## Principe

```text
énoncé
  ↓
analyse
  ↓
architecture
  ↓
implémentation
  ↓
tests
  ↓
preuves
  ↓
ZIP final
```

Les documents de ce dossier distinguent systématiquement ce qui vient directement du support de cours de ce qui relève d’une proposition d’implémentation ou de durcissement.

L’implémentation réellement exécutée sera placée dans `../Projet_Final/`.
