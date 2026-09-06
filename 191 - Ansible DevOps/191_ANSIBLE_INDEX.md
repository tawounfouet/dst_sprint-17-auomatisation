# 191 — Ansible DevOps — Index

> Sprint 17 — Automatisation

Cet index est le point d’entrée du corpus Ansible canonique du dépôt.

## Parcours principal

| Ordre | Document | Statut |
|---:|---|---|
| 1 | `191.01_ANSIBLE_INTRODUCTION_ET_INSTALLATION.md` | ✅ Canonique |
| 2 | `191.02_ANSIBLE_MODULES_ET_COMMANDES_AD_HOC.md` | ✅ Canonique |
| 3 | `191.03_ANSIBLE_INVENTAIRES.md` | ✅ Canonique |
| 4 | `191.04_ANSIBLE_PLAYBOOKS.md` | ✅ Canonique |
| 5 | `191.05_ANSIBLE_ROLES.md` | ✅ Canonique |
| 6 | `191.06_ANSIBLE_VAULT.md` | ✅ Canonique |
| 7 | `191.07_ANSIBLE_CONCLUSION_ET_PROJET_FINAL.md` | ✅ Canonique |

## Laboratoires

| Ordre | Laboratoire | Statut |
|---:|---|---|
| 1 | `labs/01-multipass-bootstrap/` | ✅ Bootstrap reproductible |
| 2 | `labs/02-modules-ad-hoc/` | ✅ Modules et commandes ad hoc |
| 3 | `labs/03-inventory/` | ✅ Inventaire structuré dev/test/prod |
| 4 | `labs/04-playbooks/` | ✅ Apache + PostgreSQL + features Playbook |
| 5 | `labs/05-roles-wordpress/` | ✅ Rôle WordPress réutilisable |
| 6 | `labs/06-vault/` | ✅ Vault + variables sensibles WordPress |

## Examen

L’évaluation finale est désormais structurée dans :

```text
Examen/
├── README.md
├── 191.07_ENONCE_EVALUATION_DATASCIENTEST.md
├── 191.07_ANALYSE_EXIGENCES.md
├── 191.07_ARCHITECTURE_CIBLE.md
├── 191.07_PLAN_IMPLEMENTATION.md
├── 191.07_CHECKLIST_VALIDATION.md
├── 191.07_STRATEGIE_TESTS.md
└── 191.07_CORRIGE_REFERENCE.md
```

Le sujet demande une solution e-commerce automatisée avec deux rôles distincts, un rôle web et un rôle MySQL, un playbook d’orchestration, des logs de tests et un rendu ZIP. Prestashop est la solution de référence ; WordPress ou Magento sont admis par le support comme alternatives valides.

## Projet final

Le dossier `Projet_Final/` accueillera l’implémentation réellement exécutée.

```text
Examen/
   │
   │ exigences / architecture / tests
   ▼
Projet_Final/
   ├── documentation
   ├── ansible-project/
   └── evidence/
```

L’objectif de l’étape suivante sera de transformer le blueprint de l’examen en code Ansible réellement exécutable, puis de produire les preuves de validation.

## Documents transverses à produire ensuite

| Document | Rôle | Statut |
|---|---|---|
| `191_ANSIBLE_ARCHITECTURE_AND_WORKFLOW.md` | architecture et modèle mental | ⏳ |
| `191_ANSIBLE_SYNTHESE_COMPLETE.md` | synthèse du module | ⏳ |
| `191_ANSIBLE_GLOSSAIRE.md` | vocabulaire | ⏳ |
| `191_ANSIBLE_MEGA_CHEATSHEET.md` | commandes essentielles | ⏳ |
| `191_ANSIBLE_BEST_PRACTICES.md` | pratiques recommandées | ⏳ |
| `191_ANSIBLE_ANTI_PATTERNS_ET_PIEGES.md` | erreurs fréquentes | ⏳ |
| `191_ANSIBLE_TROUBLESHOOTING.md` | diagnostic et résolution | ⏳ |
| `191_ANSIBLE_COMPETENCES_A_RETENIR.md` | compétences clés | ⏳ |

## Progression

```text
[1] Bootstrap documentaire              ✅
          ↓
[2] Lab Multipass                       ✅
          ↓
[3] 191.01                              ✅
          ↓
[4] 191.02 + Lab 02                     ✅
          ↓
[5] 191.03 + Lab 03                     ✅
          ↓
[6] 191.04 + Lab 04                     ✅
          ↓
[7] 191.05 + Lab 05                     ✅
          ↓
[8] 191.06 + Lab 06                     ✅
          ↓
[9] 191.07 + Examen                     ✅
          ↓
[10] Projet final réel                  ⏭️ NEXT
          ↓
[11] Synthèses et références
```

## Sources et migration

Les ressources historiques restent qualifiées dans :

`archive/migration/ANSIBLE_RESOURCE_INVENTORY_AND_MIGRATION_MAP.md`

## Règle de publication

Aucune source brute contenant des credentials, mots de passe, clés privées ou secrets réels ne doit être intégrée au dépôt public.
