# Lab 01 — Bootstrap Ansible avec Multipass

> Sprint 17 — Automatisation · 191 — Ansible DevOps

Ce laboratoire prépare l'environnement local utilisé dans les chapitres Ansible suivants. Il reprend l'adaptation du cours DataScientest qui remplace les quatre instances AWS EC2 par quatre VM Ubuntu 24.04 créées avec Multipass : un nœud de contrôle et trois nœuds cibles.

## Objectifs

À la fin du lab, on doit disposer de :

```text
Machine hôte (macOS / Linux / Windows)
        │
        └── Multipass
            ├── ansible-master
            ├── cible1
            ├── cible2
            └── cible3
```

Le rôle des machines est le suivant :

| VM | Rôle |
|---|---|
| `ansible-master` | control node Ansible |
| `cible1` | managed node |
| `cible2` | managed node |
| `cible3` | managed node |

Le cours enrichi utilise Ubuntu 24.04 et l'utilisateur `datascientest` sur les quatre VM.

## Structure du lab

```text
01-multipass-bootstrap/
├── README.md
├── .gitignore
├── ansible.cfg
├── config.yaml
└── scripts/
    └── instance_state.py
```

## 1. Prérequis

Installer Multipass sur la machine hôte, puis vérifier :

```bash
multipass version
```

Les commandes `multipass launch`, `multipass list`, `multipass info`, `multipass shell` et `multipass exec` sont exécutées depuis la machine hôte.

## 2. Préparer `config.yaml`

Le fichier fourni dans ce lab est une version publiable du `cloud-init` utilisé pendant la formation.

La source pédagogique utilisait un mot de passe fixe. Comme ce dépôt est public, il est remplacé ici par :

```text
CHANGE_ME_BEFORE_LAUNCH
```

Avant de lancer les VM, remplacez cette valeur dans votre copie locale. Ne commitez pas votre mot de passe réel.

Le `cloud-init` :

- conserve l'utilisateur par défaut ;
- crée `datascientest` ;
- ajoute cet utilisateur au groupe `sudo` ;
- lui accorde `NOPASSWD:ALL` ;
- définit Bash comme shell ;
- permet une phase initiale d'authentification SSH par mot de passe.

## 3. Lancer les quatre VM

Depuis le répertoire du lab :

```bash
multipass launch 24.04 --name ansible-master --cloud-init config.yaml
multipass launch 24.04 --name cible1 --cloud-init config.yaml
multipass launch 24.04 --name cible2 --cloud-init config.yaml
multipass launch 24.04 --name cible3 --cloud-init config.yaml
```

Vérifier :

```bash
multipass list
```

Exemple observé dans le cours :

```text
ansible-master   Running   192.168.2.5
cible1           Running   192.168.2.6
cible2           Running   192.168.2.7
cible3           Running   192.168.2.8
```

Les adresses IP peuvent être différentes sur une autre machine.

## 4. Vérifier chaque VM

```bash
multipass info ansible-master
multipass info cible1
multipass info cible2
multipass info cible3
```

On attend quatre VM Ubuntu 24.04 en état `Running`.

## 5. Entrer sur le master

```bash
multipass shell ansible-master
su - datascientest
whoami
```

Résultat attendu :

```text
datascientest
```

Le cours insiste sur ce point : les commandes Ansible doivent ensuite être lancées depuis le master avec l'utilisateur `datascientest`, et non depuis une cible.

## 6. Générer la paire de clés SSH

Sur `ansible-master`, connecté en `datascientest` :

```bash
ssh-keygen -t rsa -b 4096
```

Accepter les valeurs proposées pour créer :

```text
~/.ssh/id_rsa
~/.ssh/id_rsa.pub
```

La clé privée reste locale au master et ne doit jamais être versionnée.

## 7. Point d'attention Ubuntu 24.04

La version enrichie du cours a rencontré le cas suivant :

```text
Permission denied (publickey)
```

Le support indique que `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` peut conserver `PasswordAuthentication no` et écraser le réglage du fichier principal.

La correction documentée dans le cours s'effectue depuis la machine hôte :

```bash
for cible in cible1 cible2 cible3; do
  multipass exec "$cible" -- sudo sed -i \
    's/PasswordAuthentication no/PasswordAuthentication yes/' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

  multipass exec "$cible" -- sudo systemctl restart ssh
  echo "$cible : SSH par mot de passe activé"
done
```

Cette étape n'est à appliquer que si l'authentification par mot de passe reste bloquée.

## 8. Copier la clé publique sur les trois cibles

Depuis `ansible-master` :

```bash
ssh-copy-id datascientest@<IP_CIBLE1>
ssh-copy-id datascientest@<IP_CIBLE2>
ssh-copy-id datascientest@<IP_CIBLE3>
```

Le mot de passe temporaire est celui choisi localement dans `config.yaml`.

Valider ensuite l'accès sans mot de passe :

```bash
ssh datascientest@<IP_CIBLE1>
```

Puis faire le même test pour `cible2` et `cible3`.

## 9. Installer Ansible sur le master

Le cours d'installation Ubuntu utilise :

```bash
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install ansible
```

Vérifier :

```bash
which ansible
ansible --version
```

Le but de ce lab est uniquement de préparer le socle ; le chapitre canonique `191.01_ANSIBLE_INTRODUCTION_ET_INSTALLATION.md` détaillera ensuite l'installation et les concepts associés.

## 10. Configuration Ansible minimale

Le fichier `ansible.cfg` du lab contient :

```ini
[defaults]
host_key_checking = False
interpreter_python = auto_silent
```

Le cours utilise ces paramètres pour éviter les confirmations interactives de clés SSH pendant les TPs et supprimer le warning de détection de l'interpréteur Python.

Copier ou utiliser ce fichier depuis le répertoire de travail Ansible voulu.

## 11. Vérification des VM avec Python

Le script fourni dans :

```text
scripts/instance_state.py
```

reprend l'utilitaire pédagogique qui remplace le script AWS/Boto3 du cours original.

Il exécute :

```bash
multipass list --format json
```

et affiche uniquement les VM en état `Running`.

Depuis une machine où la commande `multipass` est disponible :

```bash
python3 scripts/instance_state.py
```

Le support précise qu'exécuter ce script directement à l'intérieur de `ansible-master` nécessiterait d'y disposer du client Multipass. Pour le TP, son exécution depuis la machine hôte est donc la voie la plus simple.

## 12. Checklist de validation

- [ ] Multipass est installé.
- [ ] `ansible-master`, `cible1`, `cible2`, `cible3` sont `Running`.
- [ ] Les quatre VM utilisent Ubuntu 24.04.
- [ ] L'utilisateur `datascientest` existe.
- [ ] Une paire de clés SSH existe sur `ansible-master`.
- [ ] La clé publique est copiée sur les trois cibles.
- [ ] `ssh datascientest@<IP>` fonctionne sans mot de passe après bootstrap.
- [ ] Ansible est installé sur `ansible-master`.
- [ ] `ansible --version` fonctionne.

## 13. Dépannage rapide

### `Permission denied (publickey)`

Vérifier la configuration SSH Ubuntu 24.04 décrite à l'étape 7, puis redémarrer `ssh` sur la cible.

### Mauvais utilisateur

```bash
whoami
```

doit afficher :

```text
datascientest
```

### Mauvaise IP

Depuis la machine hôte :

```bash
multipass list
```

Ne recopiez pas automatiquement les IP d'exemple `192.168.2.x`.

### Le script Python ne trouve pas `multipass`

Exécuter `instance_state.py` depuis la machine hôte où Multipass est installé, conformément à la note du support pédagogique.

## 14. Nettoyage

Pour arrêter les VM sans les supprimer :

```bash
multipass stop ansible-master cible1 cible2 cible3
```

Pour les redémarrer :

```bash
multipass start ansible-master cible1 cible2 cible3
```

Pour supprimer définitivement le lab :

```bash
multipass delete ansible-master cible1 cible2 cible3
multipass purge
```

## 15. Suite

Une fois ce bootstrap validé :

```text
Lab 01 — Multipass bootstrap
          ↓
191.01 — Introduction & installation
          ↓
Lab 02 — Modules et commandes ad hoc
```

Ce lab constitue donc le socle reproductible de toute la partie Ansible du Sprint 17.
