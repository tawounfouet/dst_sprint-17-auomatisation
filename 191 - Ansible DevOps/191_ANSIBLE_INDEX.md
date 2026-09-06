# 191 — Ansible DevOps — Index

> Sprint 17 — Automatisation

Cet index constitue le point d’entrée de la partie Ansible du dépôt. Il sera enrichi progressivement à mesure que les sources sont consolidées.

## Parcours principal

| Ordre | Document | Statut |
|---:|---|---|
| 1 | `191.01_ANSIBLE_INTRODUCTION_ET_INSTALLATION.md` | ✅ Canonique |
| 2 | `191.02_ANSIBLE_MODULES_ET_COMMANDES_AD_HOC.md` | ✅ Canonique |
| 3 | `191.03_ANSIBLE_INVENTAIRES.md` | ⏳ À produire |
| 4 | `191.04_ANSIBLE_PLAYBOOKS.md` | ⏳ À produire |
| 5 | `191.05_ANSIBLE_ROLES.md` | ⏳ À produire |
| 6 | `191.06_ANSIBLE_VAULT.md` | ⏳ À produire |
| 7 | `191.07_ANSIBLE_CONCLUSION_ET_PROJET_FINAL.md` | ⏳ À produire |

## Documents transverses

| Document | Rôle | Statut |
|---|---|---|
| `191_ANSIBLE_ARCHITECTURE_AND_WORKFLOW.md` | architecture, flux et modèle mental | ⏳ |
| `191_ANSIBLE_SYNTHESE_COMPLETE.md` | synthèse du module | ⏳ |
| `191_ANSIBLE_GLOSSAIRE.md` | vocabulaire | ⏳ |
| `191_ANSIBLE_MEGA_CHEATSHEET.md` | commandes essentielles | ⏳ |
| `191_ANSIBLE_BEST_PRACTICES.md` | pratiques recommandées | ⏳ |
| `191_ANSIBLE_ANTI_PATTERNS_ET_PIEGES.md` | erreurs fréquentes | ⏳ |
| `191_ANSIBLE_TROUBLESHOOTING.md` | diagnostic et résolution | ⏳ |
| `191_ANSIBLE_COMPETENCES_A_RETENIR.md` | compétences clés | ⏳ |

## Laboratoires

| Ordre | Laboratoire | Statut |
|---:|---|---|
| 1 | `labs/01-multipass-bootstrap/` | ✅ Bootstrap reproductible |
| 2 | `labs/02-modules-ad-hoc/` | ✅ Modules et commandes ad hoc |
| 3 | `labs/03-inventory/` | ⏳ |
| 4 | `labs/04-playbooks/` | ⏳ |
| 5 | `labs/05-roles-wordpress/` | ⏳ |
| 6 | `labs/06-vault/` | ⏳ |

Chaque laboratoire doit être reproductible et inclure au minimum :

- un `README.md` ;
- les fichiers de configuration nécessaires ;
- les commandes d’exécution ;
- les résultats attendus ;
- les erreurs connues ;
- les actions de nettoyage.

### Lab 01 — Multipass bootstrap

Le premier laboratoire met en place :

```text
ansible-master
├── cible1
├── cible2
└── cible3
```

avec quatre VM Ubuntu 24.04, l'utilisateur `datascientest`, une configuration SSH adaptée au TP, un `ansible.cfg` minimal et un script Python d'inventaire Multipass.

Les secrets présents dans les sources pédagogiques ne sont pas repris tels quels : le lab publié utilise des placeholders explicites.

### Lab 02 — Modules et commandes ad hoc

Le second laboratoire exploite l'infrastructure du lab 01 pour pratiquer :

```text
ping
copy
setup
file
apt
service
command
shell
ansible-doc
become (-b)
debugging -vvvv
```

Il fournit un inventaire d'exemple sans IP réelle, un fichier de test et un script de qualification non destructif.

## Examen

La partie `Examen/` sera séparée du cours afin de distinguer clairement :

```text
apprentissage
    ↓
pratique guidée
    ↓
évaluation
```

Elle contiendra l’énoncé, l’analyse des exigences, la checklist, la stratégie de validation et un corrigé de référence.

## Projet final

Le dossier `Projet_Final/` accueillera l’implémentation réellement exécutée, sa documentation et les preuves de validation.

```text
Projet_Final/
├── documentation
├── ansible-project/
└── evidence/
```

## Sources et migration

Les ressources historiques ne sont pas considérées comme documentation active. Leur qualification est suivie dans :

`archive/migration/ANSIBLE_RESOURCE_INVENTORY_AND_MIGRATION_MAP.md`

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
[5] 191.03 + Lab 03                     ⏭️ NEXT
          ↓
[6] 191.04 + Lab 04
          ↓
[7] 191.05 + Lab 05
          ↓
[8] 191.06 + Lab 06
          ↓
[9] 191.07 + Examen
          ↓
[10] Projet final
          ↓
[11] Synthèses et références
```

## Règle de publication

Aucune source brute contenant des credentials, mots de passe, clés privées ou secrets réels ne doit être intégrée au dépôt public.
