# Evidence — Django + PostgreSQL

Ce dossier reçoit les preuves générées par les scripts de qualification.

```text
evidence/
├── logs/          # sorties de déploiement Ansible
├── validation/    # sorties de validate.yml
└── screenshots/   # preuves visuelles éventuelles, ajoutées manuellement
```

Les fichiers présents ici ne doivent contenir aucun secret. Les sorties Ansible liées aux secrets utilisent `no_log: true` côté rôles/playbooks.

Les dossiers vides sont conservés via `.gitkeep`; les vraies preuves seront ajoutées uniquement après exécution réelle.
