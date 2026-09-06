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
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
       ▼                      ▼                      ▼
ansible-master             cible1                 cible2                 cible3
Ubuntu 24.04               Ubuntu 24.04           Ubuntu 24.04           Ubuntu 24.04
Control Node               Managed Node           Managed Node           Managed Node
       │                      ▲                      ▲                      ▲
       └──────────────────────┴──────────────────────┴──────────────────────┘
                                  SSH
```

Le nœud `ansible-master` exécute les commandes Ansible. Les machines `cible1`, `cible2` et `cible3` sont pilotées à distance via SSH.

Ce lab reprend l'adaptation Multipass du cours DataScientest, avec une différence volontaire de sécurité : **aucun mot de passe n'est versionné**. L'accès Ansible aux cibles est préparé par clé SSH.

---

## 2. Prérequis

Installer Multipass sur la machine hôte puis vérifier :

```bash
multipass version
multipass list
```

---

## 3. Fichiers du lab

```text
01-multipass-bootstrap/
├── README.md
├── .gitignore
├── ansible.cfg
├── config.yaml
└── scripts/
    └── instance_state.py
```

Rôle des fichiers :

| Fichier | Rôle |
|---|---|
| `config.yaml` | cloud-init commun aux 4 VMs ; crée l'utilisateur `datascientest` sans secret Git |
| `ansible.cfg` | configuration minimale du lab Ansible |
| `scripts/instance_state.py` | inventaire visuel des VMs Multipass actives |
| `.gitignore` | bloque clés privées, `.env`, Vault password et artefacts locaux |

---

## 4. Créer les quatre VMs

Depuis le répertoire du lab sur la machine hôte :

```bash
multipass launch 24.04 --name ansible-master --cloud-init config.yaml
multipass launch 24.04 --name cible1 --cloud-init config.yaml
multipass launch 24.04 --name cible2 --cloud-init config.yaml
multipass launch 24.04 --name cible3 --cloud-init config.yaml
```

Le téléchargement de l'image Ubuntu peut prendre quelques minutes lors du premier lancement.

Vérifiez ensuite :

```bash
multipass list
```

Exemple de topologie :

```text
Name             State    IPv4             Image
ansible-master   Running  192.168.2.5      Ubuntu 24.04 LTS
cible1           Running  192.168.2.6      Ubuntu 24.04 LTS
cible2           Running  192.168.2.7      Ubuntu 24.04 LTS
cible3           Running  192.168.2.8      Ubuntu 24.04 LTS
```

> Les IP ci-dessus sont des exemples. Les adresses réellement attribuées par Multipass font foi.

---

## 5. Vérifier les VMs avec le script Python

Depuis la machine hôte, où le binaire `multipass` est disponible :

```bash
python3 scripts/instance_state.py
```

Le script affiche les VMs `Running` avec :

- leur nom ;
- leur état ;
- leur première IPv4 ;
- leur release Ubuntu.

Il remplace dans le lab local le script AWS/Boto3 du cours original.

---

## 6. Se connecter au master

```bash
multipass shell ansible-master
```

La commande ouvre normalement une session avec l'utilisateur Multipass par défaut. Basculez ensuite sur l'utilisateur pédagogique créé par `config.yaml` :

```bash
sudo -iu datascientest
whoami
```

Résultat attendu :

```text
datascientest
```

---

## 7. Installer Ansible sur le master

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

## 8. Générer la paire de clés SSH Ansible

Toujours sur `ansible-master` en tant que `datascientest` :

```bash
ssh-keygen -t rsa -b 4096
```

Pour le lab, acceptez les chemins proposés.

Vous obtenez :

```text
/home/datascientest/.ssh/id_rsa
/home/datascientest/.ssh/id_rsa.pub
```

> `id_rsa` est une clé privée. Elle ne doit jamais être copiée dans le repository.

---

## 9. Distribuer la clé publique sans mot de passe

Le cours adapté utilisait initialement un mot de passe temporaire pour `ssh-copy-id`. Pour la version GitHub, on évite de versionner ou de documenter un secret fixe.

Depuis **la machine hôte**, récupérez la clé publique créée sur le master :

```bash
PUBKEY="$(multipass exec ansible-master -- sudo -u datascientest cat /home/datascientest/.ssh/id_rsa.pub)"
```

Injectez-la ensuite dans les trois cibles via Multipass :

```bash
for cible in cible1 cible2 cible3; do
  multipass exec "$cible" -- sudo -u datascientest mkdir -p /home/datascientest/.ssh
  multipass exec "$cible" -- sudo -u datascientest chmod 700 /home/datascientest/.ssh
  multipass exec "$cible" -- sudo -u datascientest bash -c "printf '%s\n' '$PUBKEY' >> /home/datascientest/.ssh/authorized_keys"
  multipass exec "$cible" -- sudo -u datascientest chmod 600 /home/datascientest/.ssh/authorized_keys
done
```

Ce bootstrap utilise Multipass uniquement pour déposer **la clé publique**. À partir de ce point, Ansible communiquera directement avec les cibles via SSH.

---

## 10. Tester SSH depuis le master

Récupérez les IP :

```bash
multipass list
```

Retournez sur le master :

```bash
multipass shell ansible-master
sudo -iu datascientest
```

Puis testez une cible :

```bash
ssh datascientest@<IP_CIBLE1>
```

La connexion doit fonctionner grâce à la clé privée `~/.ssh/id_rsa` présente sur le master.

Quittez la cible :

```bash
exit
```

---

## 11. Configuration Ansible minimale

Le fichier fourni contient :

```ini
[defaults]
host_key_checking = False
interpreter_python = auto_silent
```

Copiez-le dans le home de `datascientest` si vous souhaitez l'utiliser globalement pour ce lab :

```bash
cp ansible.cfg ~/ansible.cfg
```

Ou conservez-le à la racine d'un projet Ansible et exécutez Ansible depuis ce répertoire.

### Pourquoi ces paramètres ?

`host_key_checking = False` évite les confirmations interactives fréquentes lorsqu'on recrée des VMs Multipass.

`interpreter_python = auto_silent` demande à Ansible de détecter l'interpréteur Python des cibles sans afficher le warning de détection.

> Cette désactivation de la vérification des clés SSH est acceptable pour ce **lab local jetable**. Ce n'est pas la configuration recommandée pour un environnement de production.

---

## 12. Créer le premier inventaire

Sur `ansible-master`, créez `~/inventaire` avec les IP réellement attribuées :

```ini
cible1 ansible_host=<IP_CIBLE1> ansible_user=datascientest ansible_ssh_private_key_file=~/.ssh/id_rsa
cible2 ansible_host=<IP_CIBLE2> ansible_user=datascientest ansible_ssh_private_key_file=~/.ssh/id_rsa
cible3 ansible_host=<IP_CIBLE3> ansible_user=datascientest ansible_ssh_private_key_file=~/.ssh/id_rsa
```

Visualisez-le :

```bash
cat ~/inventaire
```

---

## 13. Test Ansible de bout en bout

Depuis `ansible-master` :

```bash
ansible all -i ~/inventaire -m ping
```

Résultat attendu sur les trois machines :

```text
cible1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Même résultat pour `cible2` et `cible3`.

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

## 14. Débogage rapide

### Voir les IP

```bash
multipass list
```

### Vérifier une VM

```bash
multipass info cible1
```

### Vérifier l'utilisateur créé

```bash
multipass exec cible1 -- id datascientest
```

### Vérifier la clé publique déposée

```bash
multipass exec cible1 -- sudo -u datascientest cat /home/datascientest/.ssh/authorized_keys
```

### Tester SSH en mode verbeux depuis le master

```bash
ssh -vvv datascientest@<IP_CIBLE1>
```

### Vérifier quelle configuration Ansible est chargée

```bash
ansible --version
```

La sortie indique le chemin du `config file` utilisé.

---

## 15. Checklist de validation

- [ ] Multipass installé.
- [ ] `ansible-master`, `cible1`, `cible2` et `cible3` sont `Running`.
- [ ] L'utilisateur `datascientest` existe sur les quatre VMs.
- [ ] Ansible est installé sur le master.
- [ ] Une paire de clés SSH existe sur le master.
- [ ] La clé publique du master est présente dans `authorized_keys` sur les trois cibles.
- [ ] Le master se connecte en SSH aux trois cibles.
- [ ] `ansible.cfg` est chargé.
- [ ] L'inventaire utilise les IP réelles.
- [ ] `ansible all -i ~/inventaire -m ping` retourne `SUCCESS` sur les trois cibles.

---

## 16. Arrêter ou détruire le lab

Arrêter :

```bash
multipass stop ansible-master cible1 cible2 cible3
```

Redémarrer :

```bash
multipass start ansible-master cible1 cible2 cible3
```

Supprimer :

```bash
multipass delete ansible-master cible1 cible2 cible3
multipass purge
```

---

## Étape suivante

Une fois ce bootstrap validé, le **Lab 02** utilisera cette infrastructure pour travailler les modules et commandes ad hoc :

```text
ping
setup
copy
apt
command
shell
```
