# Lab 04 — Playbooks Ansible avec Multipass

> **Objectif :** passer des commandes ad hoc à un déploiement reproductible avec deux plays : Apache sur une VM web et PostgreSQL sur une VM base de données.

---

## 1. Prérequis

Ce lab suppose que les étapes précédentes sont fonctionnelles :

```text
Lab 01 → Multipass + SSH
Lab 02 → modules / ad hoc
Lab 03 → inventaires
       ↓
Lab 04 → playbooks
```

Vérifications minimales :

```bash
multipass list
```

Puis sur `ansible-master` :

```bash
ansible --version
```

Les cibles doivent être joignables en SSH avec l’utilisateur `datascientest` et la clé `~/.ssh/id_rsa`.

---

## 2. Architecture du lab

```text
                         ┌────────────────────┐
                         │   ansible-master   │
                         │    control node    │
                         └─────────┬──────────┘
                                   │ SSH
                         ┌─────────┴─────────┐
                         │                   │
                         ▼                   ▼
                ┌────────────────┐   ┌──────────────────┐
                │  serveurweb1   │   │ serveurdatabase1 │
                │    cible1      │   │      cible2      │
                │                │   │                  │
                │ Apache2 :80    │   │ PostgreSQL       │
                └────────────────┘   └──────────────────┘
```

Le TP réutilise les mêmes VM Multipass que les chapitres précédents, mais leur attribue ici des rôles fonctionnels : `serveurweb` et `serveurdatabase`.

---

## 3. Arborescence

```text
04-playbooks/
├── README.md
├── .gitignore
├── ansible.cfg
├── inventaire.example.yaml
├── group_vars/
│   ├── all.yaml
│   ├── serveurweb.yaml
│   └── serveurdatabase.yaml
├── host_vars/
│   ├── serveurweb1.example.yaml
│   └── serveurdatabase1.example.yaml
├── templates/
│   └── index.html.j2
├── playbooks/
│   ├── datascientest-playbook.yaml
│   └── features-demo.yaml
└── scripts/
    └── verify_playbooks.sh
```

---

## 4. Préparer les IP locales

Depuis macOS :

```bash
multipass list
```

Exemple de lecture :

```text
ansible-master  Running  <IP_MASTER>
cible1          Running  <IP_CIBLE1>
cible2          Running  <IP_CIBLE2>
cible3          Running  <IP_CIBLE3>
```

Ne versionnez pas les IP réelles du lab si vous voulez conserver des fichiers réutilisables.

Copiez les exemples :

```bash
cp host_vars/serveurweb1.example.yaml host_vars/serveurweb1.yaml
cp host_vars/serveurdatabase1.example.yaml host_vars/serveurdatabase1.yaml
```

Puis remplacez :

```yaml
ansible_host: CHANGE_ME_IP_CIBLE1
```

et :

```yaml
ansible_host: CHANGE_ME_IP_CIBLE2
```

---

## 5. Préparer l’inventaire

Copiez :

```bash
cp inventaire.example.yaml inventaire.yaml
```

Le fichier décrit :

```text
all
├── serveurweb
│   └── serveurweb1
└── serveurdatabase
    └── serveurdatabase1
```

Inspectez :

```bash
ansible-inventory -i inventaire.yaml --graph
```

Puis :

```bash
ansible-inventory -i inventaire.yaml --list
```

---

## 6. Tester la connectivité

```bash
ansible all -i inventaire.yaml -m ping
```

Résultat attendu :

```text
serveurweb1      | SUCCESS => ... "ping": "pong"
serveurdatabase1 | SUCCESS => ... "ping": "pong"
```

En cas de `UNREACHABLE` :

```bash
ansible all -i inventaire.yaml -m ping -vvvv
```

Vérifiez ensuite :

```text
IP
ansible_user
clé privée
permissions SSH
VM démarrée
```

---

## 7. Vérifier la syntaxe du playbook

Avant toute modification distante :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml \
  --syntax-check
```

Résultat attendu :

```text
playbook: playbooks/datascientest-playbook.yaml
```

---

## 8. Lister les hôtes, tâches et tags

```bash
ansible-playbook -i inventaire.yaml playbooks/datascientest-playbook.yaml --list-hosts
```

```bash
ansible-playbook -i inventaire.yaml playbooks/datascientest-playbook.yaml --list-tasks
```

```bash
ansible-playbook -i inventaire.yaml playbooks/datascientest-playbook.yaml --list-tags
```

Vous devez retrouver les groupes :

```text
serveurweb
serveurdatabase
```

et les tags :

```text
web
db
```

---

## 9. Première exécution

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml
```

Le playbook effectue :

```text
Play 1 — serveurweb
├── update cache apt
├── installer Apache2
├── démarrer / activer Apache2
└── générer /var/www/html/index.html via Jinja2

Play 2 — serveurdatabase
├── update cache apt
├── installer PostgreSQL
└── démarrer / activer PostgreSQL
```

Le `PLAY RECAP` doit terminer avec :

```text
unreachable=0
failed=0
```

---

## 10. Vérifier Apache

Depuis `ansible-master` :

```bash
ansible serveurweb1 -i inventaire.yaml -b \
  -m command -a "systemctl is-active apache2"
```

Résultat attendu :

```text
active
```

Vérifier le fichier généré :

```bash
ansible serveurweb1 -i inventaire.yaml -b \
  -m command -a "cat /var/www/html/index.html"
```

Si l’IP est accessible depuis l’hôte :

```bash
curl http://<IP_CIBLE1>/
```

La page doit contenir le message configuré dans `group_vars/serveurweb.yaml`.

---

## 11. Vérifier PostgreSQL

```bash
ansible serveurdatabase1 -i inventaire.yaml \
  -m command -a "psql --version"
```

Puis :

```bash
ansible serveurdatabase1 -i inventaire.yaml -b \
  -m command -a "systemctl is-active postgresql"
```

Résultat attendu :

```text
active
```

---

## 12. Tester l’idempotence

Relancez exactement le même playbook :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml
```

Comparez les compteurs `changed` entre la première et la seconde exécution.

Objectif pédagogique : observer que l’état déjà conforme ne doit pas être inutilement modifié.

---

## 13. Travailler avec `--limit`

Uniquement la base :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml \
  --limit serveurdatabase1
```

Uniquement le web :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml \
  --limit serveurweb1
```

---

## 14. Travailler avec les tags

Seulement les tâches web :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml \
  --tags web
```

Seulement la base :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml \
  --tags db
```

Ignorer le web :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml \
  --skip-tags web
```

---

## 15. Tester variables, facts, `register`, conditions et boucles

Un second playbook pédagogique est fourni :

```text
playbooks/features-demo.yaml
```

Lancez :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/features-demo.yaml
```

Il montre :

```text
facts
  ↓
condition when
  ↓
register
  ↓
debug
  ↓
loop
```

Les tâches sont non destructives ou limitées à `/tmp` afin de pouvoir répéter le lab facilement.

---

## 16. Tester une extra-var

```bash
ansible-playbook \
  -i inventaire.yaml \
  -e serveurweb_message="Message fourni avec -e" \
  playbooks/datascientest-playbook.yaml \
  --tags web
```

Puis :

```bash
curl http://<IP_CIBLE1>/
```

Cette manipulation illustre le mécanisme `-e` présenté dans le support.

---

## 17. Débogage — Apache ne démarre pas

Symptôme possible :

```text
Address already in use
could not bind to address 0.0.0.0:80
```

Vérifiez d’abord l’état :

```bash
ansible serveurweb1 -i inventaire.yaml -b \
  -m command -a "systemctl status apache2"
```

Identifier le processus sur le port 80 :

```bash
ansible serveurweb1 -i inventaire.yaml -b \
  -m shell -a "ss -ltnp | grep ':80' || true"
```

Le support Multipass rapporte qu’un serveur web déjà présent, notamment Nginx dans l’environnement rencontré, peut occuper le port 80.

Ne supprimez pas automatiquement un service sans avoir identifié le processus et compris pourquoi il est présent.

---

## 18. Débogage — `command` ou `shell` ?

Cette commande contient un pipe :

```bash
ss -ltnp | grep ':80'
```

Utilisez donc explicitement :

```bash
-m shell
```

Le module `command` n’interprète pas les opérateurs de shell comme `|`, `>`, `&&`, etc.

---

## 19. Débogage — analyser un échec

Relancer avec davantage de verbosité :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml \
  -vv
```

Pour les problèmes de connexion :

```bash
-vvvv
```

Puis regarder dans le récapitulatif :

```text
unreachable
failed
skipped
```

---

## 20. Note sur un incident rapporté par le support Multipass

La version enrichie du cours rapporte un cas où un échec Apache aurait empêché l’exécution du play PostgreSQL pourtant porté par un autre hôte.

Le même support indique par ailleurs qu’Ansible arrête normalement l’exécution sur **l’hôte concerné** et continue sur les autres.

Le lab ne transforme donc pas cet incident en règle universelle : il vous invite à observer le comportement réel avec votre version d’Ansible et votre inventaire.

Pour isoler :

```bash
ansible-playbook \
  -i inventaire.yaml \
  playbooks/datascientest-playbook.yaml \
  --limit serveurdatabase1
```

---

## 21. Qualification automatique

Rendre le script exécutable :

```bash
chmod +x scripts/verify_playbooks.sh
```

Puis :

```bash
./scripts/verify_playbooks.sh
```

Le script vérifie sans déployer de nouvelle application :

```text
Ansible présent
inventaire parsable
ping des deux cibles
syntax-check
tags / hosts visibles
Apache actif si installé
PostgreSQL actif si installé
```

---

## 22. Nettoyage optionnel

Le cours ne demande pas de suppression automatique des services à la fin du TP.

Si vous souhaitez remettre les VMs dans un état plus proche du départ, faites-le volontairement avec des commandes explicites, par exemple :

```bash
ansible serveurweb1 -i inventaire.yaml -b \
  -m apt -a "name=apache2 state=absent"
```

```bash
ansible serveurdatabase1 -i inventaire.yaml -b \
  -m apt -a "name=postgresql state=absent"
```

Cette étape est optionnelle et peut modifier les labs suivants : ne l’exécutez pas si vous souhaitez conserver l’environnement.

---

## 23. Résultat attendu

À la fin du lab :

```text
✅ inventaire valide
✅ serveurweb1 joignable
✅ serveurdatabase1 joignable
✅ playbook syntaxiquement valide
✅ Apache installé et actif
✅ template Jinja2 déployé
✅ PostgreSQL installé et actif
✅ tags web/db utilisables
✅ --limit maîtrisé
✅ facts / register / debug / when / loop pratiqués
✅ PLAY RECAP interprété
```

Vous êtes alors prêt à transformer un playbook relativement monolithique en **rôle Ansible réutilisable** dans le chapitre 191.05.
