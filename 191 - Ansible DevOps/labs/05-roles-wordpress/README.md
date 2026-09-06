# Lab 05 — Rôles Ansible : WordPress + Nginx + MySQL

> **Sprint 17 — Automatisation**  
> **Chapitre associé :** `191.05_ANSIBLE_ROLES.md`

Ce laboratoire transforme le cas WordPress du support DataScientest en un **rôle Ansible réutilisable** exécuté sur l’infrastructure Multipass créée dans les labs précédents.

---

## 1. Objectifs

À la fin du lab, vous devez savoir :

- créer un rôle avec `ansible-galaxy init` ;
- comprendre la structure standard d’un rôle ;
- organiser tâches, handlers, templates et variables ;
- appeler un rôle depuis un playbook principal ;
- utiliser `include_tasks` ;
- installer les dépendances Ansible du projet ;
- déployer WordPress avec Nginx, PHP-FPM et MySQL ;
- valider le rôle et diagnostiquer les erreurs principales.

---

## 2. Prérequis

Les labs précédents doivent être opérationnels.

Depuis l’hôte macOS :

```bash
multipass list
```

Vous devez disposer au minimum de :

```text
ansible-master
cible1
cible2
cible3
```

Le lab utilise `cible1` comme serveur `production`.

```text
ansible-master
      │
      └── cible1
            └── serveurweb1
                  ├── Nginx
                  ├── PHP-FPM
                  ├── WordPress
                  └── MySQL
```

---

## 3. Structure du projet

```text
05-roles-wordpress/
├── README.md
├── .gitignore
├── ansible.cfg
├── inventaire.example.yaml
├── requirements.yml
├── install_wordpress.yaml
├── group_vars/
│   └── production.yaml
├── host_vars/
│   └── serveurweb1.example.yaml
├── scripts/
│   └── verify_role.sh
└── roles/
    └── wordpress/
        ├── README.md
        ├── defaults/main.yml
        ├── files/README.md
        ├── handlers/main.yml
        ├── meta/main.yml
        ├── tasks/main.yml
        ├── tasks/nginx.yml
        ├── templates/nginx-vhost.j2
        ├── templates/wp-config.php.j2
        ├── tests/inventory
        ├── tests/test.yml
        └── vars/main.yml
```

Cette structure reprend le rôle WordPress du support DataScientest, avec quelques adaptations nécessaires pour un dépôt public et une distribution Ansible moderne.

---

## 4. Préparer l’inventaire réel

Récupérer l’IP de `cible1` :

```bash
multipass list
```

Puis :

```bash
cp host_vars/serveurweb1.example.yaml host_vars/serveurweb1.yaml
```

Éditer :

```yaml
ansible_host: <IP_CIBLE1>
```

Le fichier réel est ignoré par Git.

---

## 5. Vérifier l’accès SSH

```bash
ansible production -i inventaire.example.yaml -m ansible.builtin.ping
```

Résultat attendu :

```text
serveurweb1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

En cas d’erreur :

```bash
ansible production -i inventaire.example.yaml \
  -m ansible.builtin.ping -vvvv
```

---

## 6. Installer les dépendances Ansible

Le rôle utilise les modules MySQL de la collection `community.mysql`.

```bash
ansible-galaxy collection install -r requirements.yml
```

Vérifier :

```bash
ansible-galaxy collection list | grep community.mysql
```

---

## 7. Comprendre le rôle

### `defaults/main.yml`

Contient les valeurs configurables :

```text
WordPress
Nginx
MySQL
PHP
```

### `tasks/main.yml`

Contient la logique principale :

```text
packages
WordPress
base MySQL
utilisateur MySQL
wp-config
permissions
include Nginx
```

### `tasks/nginx.yml`

Contient la configuration spécifique Nginx/PHP-FPM.

### `handlers/main.yml`

Contient le redémarrage Nginx déclenché uniquement si sa configuration change.

### `templates/`

Contient :

```text
nginx-vhost.j2
wp-config.php.j2
```

---

## 8. Vérifier la syntaxe

```bash
ansible-playbook -i inventaire.example.yaml \
  install_wordpress.yaml \
  --syntax-check
```

Résultat attendu :

```text
playbook: install_wordpress.yaml
```

---

## 9. Lancer la qualification avant déploiement

```bash
chmod +x scripts/verify_role.sh
./scripts/verify_role.sh
```

Le script vérifie la structure, l’inventaire, la collection et la syntaxe.

---

## 10. Déployer WordPress

```bash
ansible-playbook -i inventaire.example.yaml install_wordpress.yaml
```

Le déroulement attendu est conceptuellement :

```text
Gather facts
    ↓
PHP / Nginx / MySQL
    ↓
Téléchargement WordPress
    ↓
Base + utilisateur
    ↓
wp-config.php
    ↓
Nginx vhost
    ↓
handlers
    ↓
PLAY RECAP
```

---

## 11. Vérifier les services

### Nginx

```bash
ansible production -i inventaire.example.yaml -b \
  -m ansible.builtin.command \
  -a "systemctl is-active nginx"
```

### MySQL

```bash
ansible production -i inventaire.example.yaml -b \
  -m ansible.builtin.command \
  -a "systemctl is-active mysql"
```

### PHP-FPM

```bash
ansible production -i inventaire.example.yaml -b \
  -m ansible.builtin.shell \
  -a "systemctl is-active 'php*-fpm'"
```

---

## 12. Vérifier le site

Depuis un navigateur :

```text
http://<IP_CIBLE1>/
```

Ou depuis l’hôte :

```bash
curl -I http://<IP_CIBLE1>/
```

Le serveur doit répondre en HTTP et afficher WordPress.

---

## 13. Vérifier l’idempotence

Relancer :

```bash
ansible-playbook -i inventaire.example.yaml install_wordpress.yaml
```

L’objectif est de réduire au maximum les changements lors de la deuxième exécution.

Les tâches de lecture/détection utilisent `changed_when: false` lorsque nécessaire, et Nginx est redémarré via handler uniquement lorsque sa configuration change.

---

## 14. Différences explicites par rapport au support historique

Le support fourni montre notamment :

- un mot de passe MySQL pédagogique en clair ;
- des privilèges MySQL `*.*:ALL` ;
- des modules MySQL appelés sans nom de collection ;
- un `shell` avec plusieurs pipes pour identifier PHP-FPM.

Le lab public adapte ces points :

```text
mot de passe fictif clairement lab-only
community.mysql déclaré dans requirements.yml
privilèges limités à la base WordPress
commande PHP sans pipeline quand possible
FQCN ansible.builtin.*
```

Le chapitre 06 remplacera ensuite le secret de démonstration par un vrai fichier chiffré avec Ansible Vault.

---

## 15. Troubleshooting

### Le rôle n’est pas trouvé

```text
ERROR! the role 'wordpress' was not found
```

Vérifier :

```bash
find roles/wordpress -maxdepth 2 -type f | sort
```

et :

```bash
ansible-config dump | grep -i roles
```

---

### Collection MySQL absente

```text
couldn't resolve module/action 'community.mysql.mysql_db'
```

Corriger :

```bash
ansible-galaxy collection install -r requirements.yml
```

---

### Nginx affiche sa page par défaut

Le rôle supprime :

```text
/etc/nginx/sites-enabled/default
```

Vérifier :

```bash
sudo nginx -t
sudo ls -la /etc/nginx/sites-enabled
sudo cat /etc/nginx/conf.d/wordpress.conf
```

---

### Erreur PHP-FPM

```bash
php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'
```

Puis :

```bash
systemctl list-unit-files 'php*-fpm.service'
```

---

### Erreur MySQL

Vérifier :

```bash
sudo systemctl status mysql
sudo ls -l /var/run/mysqld/mysqld.sock
```

Les modules du lab se connectent via le socket Unix local.

---

### SSH `UNREACHABLE`

```bash
ansible production -i inventaire.example.yaml \
  -m ansible.builtin.ping -vvvv
```

Contrôler :

```text
IP
ansible_user
clé SSH
VM démarrée
```

---

## 16. Nettoyage

Pour supprimer la VM si vous souhaitez reconstruire entièrement le lab :

```bash
multipass delete cible1
multipass purge
```

Ne faites cela que si les autres labs n’en ont plus besoin.

Pour seulement désinstaller le stack applicatif, il est préférable de reconstruire une VM propre plutôt que de transformer ce rôle pédagogique en rôle de désinstallation.

---

## 17. Critères de réussite

Le lab est considéré réussi lorsque :

```text
[ ] inventaire parsable
[ ] ping production OK
[ ] community.mysql installée
[ ] syntax-check OK
[ ] rôle wordpress trouvé
[ ] Nginx actif
[ ] MySQL actif
[ ] PHP-FPM actif
[ ] WordPress accessible en HTTP
[ ] seconde exécution sans échec
```

---

## 18. Étape suivante

Ce lab introduit volontairement une donnée sensible :

```text
wp_db_password
```

La suite logique est donc :

```text
Lab 05 Roles
     ↓
Lab 06 Vault
     ↓
chiffrement de group_vars / secrets
```
