# Lab 06 — Ansible Vault

Ce laboratoire prolonge directement le **Lab 05 — Rôles WordPress**.

Le support DataScientest demande de chiffrer `group_vars/production.yaml`, puis de relancer `install_wordpress.yaml` en fournissant le mot de passe Vault.

## Objectif

Passer de :

```text
production.yaml en clair
        ↓
secret lisible
```

à :

```text
production.yaml
        ↓
ansible-vault encrypt
        ↓
$ANSIBLE_VAULT;...
        ↓
ansible-playbook --ask-vault-pass
```

## Prérequis

- les Labs 01 à 05 sont compris ;
- le projet WordPress du Lab 05 est disponible ;
- `ansible-vault` est installé avec Ansible ;
- le rôle WordPress fonctionne déjà avant chiffrement ;
- aucun secret réel n’est versionné.

## Arborescence

```text
06-vault/
├── README.md
├── .gitignore
├── ansible.cfg
├── group_vars/
│   └── production.example.yaml
└── scripts/
    └── verify_vault.sh
```

Le lab est volontairement léger : le rôle WordPress reste dans `../05-roles-wordpress/` afin d’éviter de dupliquer deux versions du même rôle.

## 1. Préparer le fichier de variables

Dans le Lab 06 :

```bash
cp group_vars/production.example.yaml group_vars/production.yaml
```

Le fichier contient :

```yaml
---
ansible_user: datascientest
ansible_ssh_private_key_file: ~/.ssh/id_rsa
wp_db_password: CHANGE_ME_WITH_VAULT
```

Remplacez localement `CHANGE_ME_WITH_VAULT` par une valeur de laboratoire avant de chiffrer le fichier.

> Ne commitez jamais cette version en clair.

## 2. Chiffrer le fichier

```bash
ansible-vault encrypt group_vars/production.yaml
```

Ansible demande :

```text
New Vault password:
Confirm New Vault password:
Encryption successful
```

## 3. Vérifier le chiffrement

```bash
head -n 1 group_vars/production.yaml
```

Résultat attendu :

```text
$ANSIBLE_VAULT;1.1;AES256
```

Le numéro de format peut évoluer ; l’élément important est la présence de l’en-tête `$ANSIBLE_VAULT;`.

## 4. Afficher le contenu

```bash
ansible-vault view group_vars/production.yaml
```

Le mot de passe est demandé, puis le contenu est affiché.

## 5. Modifier le fichier chiffré

```bash
ansible-vault edit group_vars/production.yaml
```

Utilisez cette commande plutôt que de déchiffrer durablement le fichier uniquement pour faire une petite modification.

## 6. Changer le mot de passe

```bash
ansible-vault rekey group_vars/production.yaml
```

Sortie attendue :

```text
Vault password:
New Vault password:
Confirm New Vault password:
Rekey successful
```

## 7. Déchiffrer explicitement

Le support présente également :

```bash
ansible-vault decrypt group_vars/production.yaml
```

Cette commande remet le fichier en clair. Pour le TP, rechiffrez-le ensuite si vous souhaitez poursuivre avec Vault.

## 8. Réutiliser le projet WordPress

Le Lab 05 contient déjà :

```text
../05-roles-wordpress/
├── install_wordpress.yaml
├── inventaire.example.yaml
├── group_vars/
├── host_vars/
└── roles/wordpress/
```

Pour reproduire exactement l’exercice du support, placez le fichier Vault dans le projet WordPress local.

Par exemple, depuis `06-vault/` :

```bash
cp group_vars/production.yaml ../05-roles-wordpress/group_vars/production.yaml
```

Le fichier reste chiffré pendant cette copie.

## 9. Exécuter avec `--ask-vault-pass`

Dans le Lab 05 :

```bash
cd ../05-roles-wordpress
```

Préparez les fichiers locaux du Lab 05 si ce n’est pas déjà fait :

```bash
cp inventaire.example.yaml inventaire.yaml
cp host_vars/serveurweb1.example.yaml host_vars/serveurweb1.yaml
```

Renseignez l’IP actuelle de `cible1`, puis lancez :

```bash
ansible-playbook \
  -i inventaire.yaml \
  install_wordpress.yaml \
  --ask-vault-pass
```

Ansible demande :

```text
Vault password:
```

Le résultat attendu est un playbook capable de charger les variables du groupe `production` et d’exécuter le rôle WordPress.

## 10. Alternative avec fichier de mot de passe

Le support enrichi propose :

```bash
printf '%s\n' '<VAULT_PASSWORD>' > ~/.vault_pass
chmod 600 ~/.vault_pass
```

Puis :

```bash
ansible-playbook \
  -i inventaire.yaml \
  install_wordpress.yaml \
  --vault-password-file ~/.vault_pass
```

Le fichier `~/.vault_pass` doit rester hors Git.

## 11. Variante via `ansible.cfg`

Le support montre aussi :

```ini
[defaults]
vault_password_file = ~/.vault_pass
```

Le `ansible.cfg` livré dans ce lab ne l’active pas par défaut afin de garder le TP utilisable même si `~/.vault_pass` n’existe pas.

Vous pouvez ajouter temporairement cette ligne sur votre machine pour tester le comportement.

## 12. Script de qualification

Après chiffrement :

```bash
./scripts/verify_vault.sh
```

Le script vérifie :

```text
ansible-vault disponible
        ↓
production.yaml présent
        ↓
en-tête $ANSIBLE_VAULT
        ↓
permissions de ~/.vault_pass si présent
```

Vous pouvez également fournir un fichier de mot de passe pour vérifier que Vault arrive réellement à lire le fichier :

```bash
VAULT_PASSWORD_FILE=~/.vault_pass ./scripts/verify_vault.sh
```

Dans ce cas, le script exécute un `ansible-vault view` silencieux.

## 13. Nettoyage

Pour éviter de laisser une copie en clair :

```bash
rm -f group_vars/production.yaml
```

Si vous avez copié le fichier dans le Lab 05 et ne souhaitez pas le conserver :

```bash
rm -f ../05-roles-wordpress/group_vars/production.yaml
```

Le fichier de mot de passe éventuel reste sous votre contrôle :

```bash
rm -f ~/.vault_pass
```

si vous n’en avez plus besoin.

## Résultat attendu

À la fin du lab :

```text
[OK] ansible-vault disponible
[OK] fichier chiffré
[OK] view / edit compris
[OK] rekey compris
[OK] --ask-vault-pass compris
[OK] --vault-password-file compris
[OK] rôle WordPress exécutable avec variables Vault
```

Le prochain chapitre est `191.07_ANSIBLE_CONCLUSION_ET_PROJET_FINAL.md`.
