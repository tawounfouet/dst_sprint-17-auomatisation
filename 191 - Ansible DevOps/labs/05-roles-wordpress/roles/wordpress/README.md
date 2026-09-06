# Role `wordpress`

Rôle pédagogique issu du chapitre DataScientest sur les rôles Ansible.

Il installe sur Ubuntu 24.04 :

- Nginx ;
- PHP-FPM ;
- WordPress ;
- MySQL ;
- une base et un utilisateur applicatif dédiés.

## Variables principales

Voir `defaults/main.yml`.

Le mot de passe par défaut est volontairement un **secret fictif de laboratoire**. Il ne doit pas être réutilisé hors environnement jetable. Le chapitre suivant remplace ce mécanisme par Ansible Vault.

## Dépendance

```bash
ansible-galaxy collection install community.mysql
```

ou :

```bash
ansible-galaxy collection install -r requirements.yml
```

## Usage

```yaml
- hosts: production
  become: true
  roles:
    - wordpress
```
