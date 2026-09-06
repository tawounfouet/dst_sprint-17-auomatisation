# 191 — Ansible DevOps

Ce répertoire regroupe les ressources canoniques du module **Ansible** du Sprint 17 — Automatisation de DataScientest.

## Objectifs

La partie Ansible vise à documenter et pratiquer :

- l’architecture et le fonctionnement d’Ansible ;
- l’installation et la configuration du control node ;
- les modules et commandes ad hoc ;
- les inventaires statiques et leur organisation ;
- les playbooks, variables, facts, conditions, boucles, handlers et templates ;
- les rôles et Ansible Galaxy ;
- Ansible Vault et la gestion des secrets ;
- la mise en œuvre de laboratoires reproductibles ;
- l’évaluation et le projet final.

## Organisation cible

```text
191 - Ansible DevOps/
├── README.md
├── .gitignore
├── 191.01_ANSIBLE_INTRODUCTION_ET_INSTALLATION.md
├── 191.02_ANSIBLE_MODULES_ET_COMMANDES_AD_HOC.md
├── 191.03_ANSIBLE_INVENTAIRES.md
├── 191.04_ANSIBLE_PLAYBOOKS.md
├── 191.05_ANSIBLE_ROLES.md
├── 191.06_ANSIBLE_VAULT.md
├── 191.07_ANSIBLE_CONCLUSION_ET_PROJET_FINAL.md
├── 191_ANSIBLE_INDEX.md
├── 191_ANSIBLE_ARCHITECTURE_AND_WORKFLOW.md
├── 191_ANSIBLE_SYNTHESE_COMPLETE.md
├── references/
├── labs/
├── Examen/
├── Projet_Final/
├── resources/
└── archive/
```

## Principe documentaire

Les documents `191.*` ne sont pas des copies brutes des supports de cours. Ils seront consolidés à partir de plusieurs couches :

```text
Cours DataScientest original
          +
Version pratique Multipass / Ubuntu 24.04
          +
TP réellement exécutés
          +
Bugs, troubleshooting et retours d'expérience
          ↓
Documentation canonique 191.*
```

## Sécurité

Ce dépôt est public. Aucun secret réel ne doit être versionné :

- credentials AWS ;
- clés SSH privées ;
- fichiers `.pem` ;
- `.env` ;
- mots de passe Vault ;
- tokens ou API keys ;
- secrets applicatifs.

Les exemples doivent utiliser des placeholders tels que `CHANGE_ME`, `<REDACTED>` ou des valeurs strictement pédagogiques.

## Statut

La partie Ansible est en cours de consolidation. La première phase consiste à inventorier et qualifier les ressources existantes avant de produire les chapitres canoniques et les laboratoires.
