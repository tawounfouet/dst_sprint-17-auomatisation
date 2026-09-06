# Lab 01 — Bootstrap Ansible avec Multipass

> **Sprint 17 — Automatisation / Ansible**  
> Objectif : disposer d'un environnement local reproductible composé de **4 VMs Ubuntu 24.04** : 1 nœud de contrôle Ansible et 3 machines cibles.

---

## 1. Architecture du lab

```text
                         Machine hôte
                    macOS / Linux / Windows
                              │
                          Multipass
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
  ansible-master          cible1              cible2              cible3
  Ubuntu 24.04            Ubuntu 24.04         Ubuntu 24.04         Ubuntu 24.04
  Control Node            Managed Node         Managed Node         Managed Node
          │                   ▲                   ▲                   ▲
          └───────────────────┴───────────────────┴───────────────────┘
                               SSH
```

Le nœud `ansible-master` exécute les commandes Ansible. Les machines `cible1`, `cible2` et `cible3` sont pilotées à distance via SSH.

---

## 2. Prérequis

Installer Multipass sur la machine hôte :

- macOS
- Linux
- Windows

Vérifier l'installation :

```bash
multipass version
```

Puis contrôler les éventuelles VMs existantes :

```bash
multipass list
```

---

## 3. Préparer le cloud-init

Le fichier versionné `config.yaml` contient volontairement un mot de passe factice :

```text
CHANGE_ME_BEFORE_LAUNCH
```

Ne versionnez pas de mot de passe réel dans Git.

Créez une copie locale :

```bash
cp config.yaml config.local.yaml
```

Puis remplacez `CHANGE_ME_BEFORE_LAUNCH` par un mot de passe de lab dans **`config.local.yaml` uniquement**.

Le fichier local est ignoré par `.gitignore`.

---

## 4. Créer les quatre VMs

Depuis le répertoire de ce lab :

```bash
multipass launch 24.04 --name ansible-master --cloud-init config.local.yaml
multipass launch 24.04 --name cible1 --cloud-init config.local.yaml
multipass launch 24.04 --name cible2 --cloud-init config.local.yaml
multipass launch 24.04 --name cible3 --cloud-init config.local.yaml
```

Le téléchargement de l'image Ubuntu peut prendre quelques minutes lors du premier lancement.

Vérifiez ensuite l'état des machines :

```bash
multipass list
```

Exemple de topologie obtenue :

```text
Name             State    IPv4             Image
ansible-master   Running  192.168.2.5      Ubuntu 24.04 LTS
cible1           Running  192.168.2.6      Ubuntu 24.04 LTS
cible2           Running  192.168.2.7      Ubuntu 24.04 LTS
cible3           Running  192.168.2.8      Ubuntu 24.04 LTS
```

> Les adresses IP sont des exemples. Utilisez toujours les IP réellement retournées par `multipass list`.

---

## 5. Se connecter au master

```bash
multipass shell ansible-master
```

Puis basculez sur l'utilisateur du cours :

```bash
su - datascientest
whoami
```

Résultat attendu :

```text
datascientest
```

---

## 6. Installer Ansible sur le master

Sur `ansible-master` :

```bash
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible
```

Vérifiez :

```bash
which ansible
ansible --version
```

Le chemin attendu est généralement :

```text
/usr/bin/ansible
```

---

## 7. Générer une clé SSH sur le master

Toujours en tant que `datascientest` :

```bash
ssh-keygen -t rsa -b 4096
```

Acceptez les valeurs proposées pour ce lab.

Vous devez obtenir :

```text
~/.ssh/id_rsa
~/.ssh/id_rsa.pub
```

> La clé privée `id_rsa` ne doit jamais être ajoutée au repository.

---

## 8. Déployer la clé publique sur les cibles

Récupérez d'abord les IP depuis la machine hôte :

```bash
multipass list
```

Depuis `ansible-master`, copiez ensuite la clé publique :

```bash
ssh-copy-id datascientest@<IP_CIBLE1>
ssh-copy-id datascientest@<IP_CIBLE2>
ssh-copy-id datascientest@<IP_CIBLE3>
```

Validez la connexion sans mot de passe :

```bash
ssh datascientest@<IP_CIBLE1>
```

Puis quittez la cible :

```bash
exit
```

---

## 9. Particularité Ubuntu 24.04 : authentification SSH

Sur certaines images Ubuntu 24.04, le fichier :

```text
/etc/ssh/sshd_config.d/60-cloudimg-settings.conf
```

peut imposer :

```text
PasswordAuthentication no
```

et prendre le dessus sur `/etc/ssh/sshd_config`.

Le `config.yaml` de ce lab traite ce cas afin de rendre le bootstrap pédagogique reproductible.

En cas d'échec de `ssh-copy-id`, vérifiez sur une cible :

```bash
sudo grep -R "PasswordAuthentication" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/
```

Puis contrôlez le service :

```bash
sudo systemctl status ssh
```

---

## 10. Configuration Ansible minimale

Copiez le fichier `ansible.cfg` du lab dans le home de `datascientest` :

```bash
cp ansible.cfg ~/ansible.cfg
```

Contenu :

```ini
[defaults]
host_key_checking = False
interpreter_python = auto_silent
```

Cette configuration est adaptée au **lab local** :

- `host_key_checking = False` évite les confirmations interactives lors des recréations de VMs ;
- `interpreter_python = auto_silent` laisse Ansible détecter Python sur les cibles sans warning inutile.

> En production, la désactivation globale de la vérification des clés SSH n'est pas une recommandation de sécurité.

---

## 11. Premier inventaire

Créez `~/inventaire` sur le master avec les IP réellement attribuées :

```ini
cible1 ansible_host=<IP_CIBLE1> ansible_user=datascientest ansible_ssh_private_key_file=~/.ssh/id_rsa
cible2 ansible_host=<IP_CIBLE2> ansible_user=datascientest ansible_ssh_private_key_file=~/.ssh/id_rsa
cible3 ansible_host=<IP_CIBLE3> ansible_user=datascientest ansible_ssh_private_key_file=~/.ssh/id_rsa
```

---

## 12. Test de bout en bout

Depuis `ansible-master` :

```bash
ansible all -i ~/inventaire -m ping
```

Résultat attendu pour chaque cible :

```text
SUCCESS
ping: pong
```

Architecture validée :

```text
ansible-master
     │
     │ ansible + SSH
     │
     ├────────────► cible1  ✓
     ├────────────► cible2  ✓
     └────────────► cible3  ✓
```

---

## 13. Script `instance_state.py`

Le script présent dans `scripts/instance_state.py` reproduit localement l'objectif du script AWS/Boto3 utilisé dans le cours original : afficher les instances actives et leurs informations principales.

Il doit être exécuté depuis une machine qui dispose de la commande `multipass` :

```bash
python3 scripts/instance_state.py
```

Il affiche notamment :

- nom ;
- état ;
- adresse IPv4 ;
- release Ubuntu.

---

## 14. Checklist de validation

- [ ] Multipass installé.
- [ ] `ansible-master` démarré.
- [ ] `cible1`, `cible2`, `cible3` démarrées.
- [ ] utilisateur `datascientest` disponible.
- [ ] Ansible installé sur le master.
- [ ] clé SSH générée sur le master.
- [ ] clé publique copiée sur les trois cibles.
- [ ] connexions SSH fonctionnelles sans mot de passe.
- [ ] `ansible.cfg` chargé.
- [ ] inventaire créé avec les IP réelles.
- [ ] `ansible all -i ~/inventaire -m ping` retourne `SUCCESS` sur les trois cibles.

---

## 15. Arrêter le lab

Quand vous avez terminé :

```bash
multipass stop ansible-master cible1 cible2 cible3
```

Pour les redémarrer :

```bash
multipass start ansible-master cible1 cible2 cible3
```

Pour supprimer complètement le lab :

```bash
multipass delete ansible-master cible1 cible2 cible3
multipass purge
```

---

## Étape suivante

Une fois ce bootstrap validé, le prochain lab est consacré aux **modules Ansible et aux commandes ad hoc** : `ping`, `setup`, `copy`, `apt`, `command` et `shell`.
