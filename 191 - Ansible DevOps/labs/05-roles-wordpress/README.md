# Lab 05 — Transformer le déploiement WordPress en rôle Ansible

Ce laboratoire reprend le TP DataScientest **Rôles** dans l’environnement Multipass utilisé depuis le début du module.

## Objectif

Transformer le déploiement WordPress du chapitre Playbooks en un rôle réutilisable :

```text
ansible-master
    │
    └── cible1
          └── serveurweb1
                └── production
                      │
                      └── role wordpress
                          ├── PHP
                          ├── Nginx
                          ├── WordPress
                          └── MySQL
```

Le support pédagogique installe ici WordPress et MySQL sur une seule machine. La séparation en rôles distincts web/base de données sera demandée plus tard dans l’évaluation finale.

## Prérequis

- les VM du Lab 01 sont démarrées ;
- Ansible est installé sur `ansible-master` ;
- la clé SSH du compte `datascientest` permet de joindre `cible1` ;
- vous connaissez l’IP actuelle de `cible1` via `multipass list` ;
- les concepts `group_vars`, `host_vars`, playbooks et templates du Lab 04 sont acquis.

## Arborescence

```text
05-roles-wordpress/
├── README.md
├── .gitignore
├── ansible.cfg
├── inventaire.example.yaml
├── install_wordpress.yaml
├── group_vars/
│   └── production.example.yaml
├── host_vars/
│   └── serveurweb1.example.yaml
├── scripts/
│   └── verify_role.sh
└── roles/
    └── wordpress/
        ├── README.md
        ├── defaults/main.yml
        ├── handlers/main.yml
        ├── meta/main.yml
        ├── tasks/main.yml
        ├── tasks/nginx.yaml
        ├── templates/nginx-vhost.j2
        ├── templates/wp-config.php.j2
        ├── tests/inventory.example
        ├── tests/test.yml
        └── vars/main.yml
```

## 1. Préparer les fichiers locaux

Copiez les exemples :

```bash
cp inventaire.example.yaml inventaire.yaml
cp group_vars/production.example.yaml group_vars/production.yaml
cp host_vars/serveurweb1.example.yaml host_vars/serveurweb1.yaml
```

Renseignez dans `host_vars/serveurweb1.yaml` :

```yaml
ansible_host: <IP_CIBLE1>
```

Le mot de passe MySQL du dépôt est un placeholder :

```yaml
wp_db_password: CHANGE_ME_WITH_VAULT
```

Pour ce TP local uniquement, remplacez-le temporairement par une valeur de laboratoire. Le chapitre suivant montrera comment chiffrer cette variable avec Ansible Vault.

## 2. Vérifier la connectivité

```bash
ansible all -i inventaire.yaml -m ping
```

Résultat attendu :

```text
serveurweb1 | SUCCESS
```

En cas de `UNREACHABLE`, revenez aux diagnostics SSH des Labs 01 et 02.

## 3. Observer la structure d’un rôle

Le support crée le squelette avec :

```bash
mkdir -p roles
cd roles
ansible-galaxy init wordpress
```

Le rôle présent dans ce repository correspond à cette structure, déjà alimentée avec les fichiers du TP.

Vous pouvez comparer :

```bash
find roles/wordpress -maxdepth 2 -type f | sort
```

## 4. Vérifier la syntaxe

```bash
ansible-playbook -i inventaire.yaml install_wordpress.yaml --syntax-check
```

Puis :

```bash
./scripts/verify_role.sh
```

Le script vérifie la structure du rôle, l’inventaire, la syntaxe du playbook et, si `inventaire.yaml` existe, tente un `ping` vers la cible.

## 5. Exécuter le rôle

```bash
ansible-playbook -i inventaire.yaml install_wordpress.yaml
```

Le flux attendu est :

```text
roles: wordpress
      │
      ├── defaults/main.yml
      ├── tasks/main.yml
      │      └── include_tasks nginx.yaml
      ├── templates/
      └── handlers/main.yml
```

## 6. Vérifier les services

```bash
ansible serveurweb1 -i inventaire.yaml -b -m shell -a "systemctl is-active nginx"
ansible serveurweb1 -i inventaire.yaml -b -m shell -a "systemctl is-active mysql"
ansible serveurweb1 -i inventaire.yaml -b -m shell -a "ls /var/run/php/"
```

Vérifier Nginx :

```bash
ansible serveurweb1 -i inventaire.yaml -b -m command -a "nginx -t"
```

## 7. Vérifier WordPress

```bash
curl -L http://<IP_CIBLE1> | head
```

Le support attend l’affichage de la page d’installation WordPress.

## 8. Dépannage — Nginx retourne une page vide ou le mauvais site

Le support Multipass documente un incident fréquent : le site par défaut Nginx peut masquer le vhost WordPress.

Diagnostic :

```bash
ansible serveurweb1 -i inventaire.yaml -b -m shell -a "ss -tlnp | grep ':80'"
ansible serveurweb1 -i inventaire.yaml -b -m command -a "nginx -t"
ansible serveurweb1 -i inventaire.yaml -b -m shell -a "ls /var/run/php/"
ansible serveurweb1 -i inventaire.yaml -b -m shell -a "cat /etc/nginx/conf.d/wordpress.conf"
ansible serveurweb1 -i inventaire.yaml -b -m shell -a "ls /etc/nginx/sites-enabled/"
```

Le rôle contient la tâche :

```yaml
- name: Nginx - Suppression du vhost par défaut
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify:
    - Nginx - Redémarrage
```

## 9. Observer les handlers

Modifiez temporairement `wp_sitename` puis relancez le playbook.

La modification du template Nginx doit notifier :

```text
Nginx - Redémarrage
```

Cela illustre le mécanisme :

```text
configuration modifiée
      ↓
notify
      ↓
handler
      ↓
restart nginx
```

## 10. Relancer pour observer l’idempotence

```bash
ansible-playbook -i inventaire.yaml install_wordpress.yaml
```

Comparez les valeurs `ok` et `changed` entre la première et la seconde exécution.

Certaines opérations du support, notamment la récupération dynamique des sels ou la commande shell de détection PHP, peuvent continuer à apparaître comme changées. Le but ici est de comprendre le comportement du rôle tel qu’enseigné.

## 11. Commandes Galaxy utiles pour le chapitre

```bash
ansible-galaxy --help
ansible-galaxy role --help
ansible-galaxy init demo_role
```

Le TP utilise Galaxy pour **initialiser** le rôle. Il ne demande pas de publier le rôle sur Galaxy.

## 12. Nettoyage

Pour repartir de zéro, le moyen le plus simple dans ce parcours est de restaurer ou recréer `cible1` depuis le Lab 01.

Les fichiers locaux suivants ne doivent pas être commités :

```text
inventaire.yaml
group_vars/production.yaml
host_vars/serveurweb1.yaml
.vault_pass
```

## Résultat attendu

À la fin du lab :

```text
[OK] structure rôle
[OK] syntax-check
[OK] inventaire
[OK] SSH/ping
[OK] nginx
[OK] mysql
[OK] WordPress accessible
```

Le prochain laboratoire réutilisera directement `group_vars/production.yaml` pour introduire **Ansible Vault**.