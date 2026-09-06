# Tests statiques — LOT 09

`static_checks.sh` constitue la barrière de qualité avant la qualification E2E.

Il vérifie la structure Ansible, le scaffold Django, la syntaxe Bash et Python, le YAML lorsque PyYAML est disponible, les invariants de sécurité (`.venv`, SCRAM, Gunicorn local, absence de wildcard `ALLOWED_HOSTS`), ainsi que l'absence de fichiers sensibles versionnés.

Lorsque `ansible-playbook` est disponible, le script exécute aussi les `--syntax-check` de `site.yml` et `validate.yml`. Si le Vault réel est absent, un fichier factice non secret est créé temporairement puis supprimé. Si un Vault chiffré existe sans moyen de le déchiffrer, le syntax-check de `site.yml` est explicitement ignoré plutôt que de demander ou d'exposer un secret.

Exécution :

```bash
cd ansible-project
./tests/static_checks.sh
```

Ces contrôles ne prouvent ni le démarrage des services, ni la connectivité réseau, ni les réponses HTTP, ni l'idempotence. Ces preuves appartiennent aux LOT 10 à 13.
