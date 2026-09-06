# Lab 02 — Modules et commandes ad hoc

> **Dépendance :** `../01-multipass-bootstrap/`  
> **Objectif :** pratiquer les modules et commandes ad hoc étudiés dans `191.02_ANSIBLE_MODULES_ET_COMMANDES_AD_HOC.md`.

---

## 1. Architecture du lab

```text
macOS / hôte Multipass
        │
        └── ansible-master
               │
               ├── SSH ──> cible1
               ├── SSH ──> cible2
               └── SSH ──> cible3
```

Toutes les commandes Ansible sont exécutées depuis `ansible-master`, sous l’utilisateur `datascientest`.

---

## 2. Prérequis

Depuis l’hôte :

```bash
multipass list
```

Les quatre VM doivent être démarrées.

Puis :

```bash
multipass shell ansible-master
su - datascientest
whoami
ansible --version
```

Résultat attendu pour `whoami` :

```text
datascientest
```

Vérifier la clé SSH :

```bash
ls -la ~/.ssh/
```

Tester directement une cible :

```bash
ssh datascientest@<IP_CIBLE1>
```

La connexion doit fonctionner avec la clé configurée dans le lab 01.

---

## 3. Préparer le répertoire de travail

```bash
mkdir -p ~/datascientest_ansible/modules-ad-hoc
cd ~/datascientest_ansible/modules-ad-hoc
```

Copier ou recréer les fichiers fournis avec ce lab :

```text
ansible.cfg
inventaire.example.ini
files/test.txt
```

Créer l’inventaire local :

```bash
cp inventaire.example.ini inventaire.ini
```

Récupérer les IP actuelles depuis l’hôte Multipass puis remplacer :

```text
<IP_CIBLE1>
<IP_CIBLE2>
<IP_CIBLE3>
```

Le fichier `inventaire.ini` est volontairement ignoré par Git dans ce lab afin de ne pas versionner des valeurs propres à une session locale.

---

## 4. Vérifier `ansible.cfg`

Contenu :

```ini
[defaults]
host_key_checking = False
interpreter_python = auto_silent
```

Vérifier la configuration effectivement utilisée :

```bash
ansible --version
```

La sortie indique notamment le fichier de configuration lu.

---

## 5. Test 1 — `ping`

Toutes les cibles :

```bash
ansible all -i inventaire.ini -m ping
```

Une cible :

```bash
ansible cible1 -i inventaire.ini -m ping
```

Sortie attendue :

```text
cible1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Validation

- [ ] `cible1` répond ;
- [ ] `cible2` répond ;
- [ ] `cible3` répond ;
- [ ] aucune authentification interactive n’est demandée.

---

## 6. Test 2 — `copy`

Afficher le fichier source :

```bash
cat files/test.txt
```

Copier sur toutes les cibles :

```bash
ansible all -i inventaire.ini -m copy -a "src=files/test.txt dest=/home/datascientest/test.txt"
```

Première exécution :

```text
CHANGED
```

Rejouer exactement la même commande :

```bash
ansible all -i inventaire.ini -m copy -a "src=files/test.txt dest=/home/datascientest/test.txt"
```

La seconde exécution permet d’observer le comportement idempotent lorsque le fichier est déjà conforme.

Vérification distante :

```bash
ansible all -i inventaire.ini -m command -a "cat /home/datascientest/test.txt"
```

---

## 7. Test 3 — `setup`

Tous les facts de `cible1` :

```bash
ansible cible1 -i inventaire.ini -m setup
```

Virtualisation :

```bash
ansible cible1 -i inventaire.ini -m setup -a "filter=ansible_virtualization_type"
```

Mémoire :

```bash
ansible cible1 -i inventaire.ini -m setup -a "filter=ansible_*_mb"
```

### Objectif pédagogique

Comprendre que `setup` collecte des informations système qui deviendront des variables exploitables dans les playbooks.

---

## 8. Test 4 — `file`

Créer un répertoire sur `cible1` :

```bash
ansible cible1 -i inventaire.ini -b -m file -a "path=/etc/datascientest state=directory mode=0755"
```

Rejouer la commande et comparer `changed`.

Supprimer le répertoire en fin de lab :

```bash
ansible cible1 -i inventaire.ini -b -m file -a "path=/etc/datascientest state=absent"
```

---

## 9. Test 5 — installer Nginx sur `cible2`

Mettre à jour le cache APT :

```bash
ansible cible2 -i inventaire.ini -b -m apt -a "update_cache=yes cache_valid_time=86400"
```

Installer Nginx comme dans le support :

```bash
ansible cible2 -i inventaire.ini -b -m apt -a "name=nginx state=latest"
```

Vérifier le paquet :

```bash
ansible cible2 -i inventaire.ini -m command -a "dpkg -s nginx"
```

Vérifier le service :

```bash
ansible cible2 -i inventaire.ini -b -m service -a "name=nginx state=started"
```

---

## 10. Test 6 — supprimer Nginx

```bash
ansible cible2 -i inventaire.ini -b -m apt -a "name=nginx state=absent"
```

Vérifier :

```bash
ansible cible2 -i inventaire.ini -m command -a "dpkg -s nginx"
```

Cette dernière commande peut retourner une erreur puisque le paquet a volontairement été supprimé. L’objectif est justement d’apprendre à distinguer une erreur de vérification attendue d’un échec de l’automatisation principale.

---

## 11. Test 7 — `command` et `shell`

### `command`

```bash
ansible cible1 -i inventaire.ini -m command -a "uname -a"
```

### `shell`

```bash
ansible cible1 -i inventaire.ini -m shell -a 'echo $HOME'
```

Comparer :

```bash
ansible cible1 -i inventaire.ini -m command -a 'echo $HOME'
ansible cible1 -i inventaire.ini -m shell -a 'echo $HOME'
```

Le but est d’observer concrètement la différence introduite par le passage par un shell.

---

## 12. Lire la documentation des modules

```bash
ansible-doc ping
ansible-doc copy
ansible-doc setup
ansible-doc apt
ansible-doc file
ansible-doc service
ansible-doc command
ansible-doc shell
```

Exercice : trouver dans `ansible-doc copy` l’option permettant de définir les permissions du fichier destination.

---

## 13. Debugging — `UNREACHABLE`

Créer une copie de l’inventaire :

```bash
cp inventaire.ini inventaire.debug.ini
```

Modifier volontairement l’IP de `cible1` par une valeur incorrecte, puis :

```bash
ansible cible1 -i inventaire.debug.ini -m ping
```

Relancer avec davantage de verbosité :

```bash
ansible cible1 -i inventaire.debug.ini -m ping -vvvv
```

Observer :

```text
inventaire
   ↓
adresse IP
   ↓
connexion SSH
   ↓
UNREACHABLE
```

Ne pas oublier de supprimer le fichier de debug ensuite.

---

## 14. Debugging — mauvais utilisateur

Sur `ansible-master` :

```bash
whoami
```

Si l’utilisateur courant n’est pas `datascientest` :

```bash
su - datascientest
```

Pourquoi cela compte : la version Multipass du cours documente le cas où `~/ansible.cfg`, l’inventaire et la clé SSH ont été préparés dans le home de `datascientest`.

---

## 15. Debugging — SSH

Test le plus direct :

```bash
ssh -vvv datascientest@<IP_CIBLE1>
```

Puis comparer avec :

```bash
ansible cible1 -i inventaire.ini -m ping -vvvv
```

Ordre recommandé :

```text
VM Running ?
    ↓
IP correcte ?
    ↓
SSH direct fonctionne ?
    ↓
clé privée correcte ?
    ↓
inventaire correct ?
    ↓
Ansible ping ?
```

---

## 16. Script de qualification

Le dossier `scripts/` contient :

```text
verify_lab.sh
```

Après adaptation de `inventaire.ini` :

```bash
chmod +x scripts/verify_lab.sh
./scripts/verify_lab.sh
```

Le script effectue uniquement des vérifications non destructives :

- présence d’Ansible ;
- présence de l’inventaire ;
- parsing de l’inventaire ;
- `ping` sur les cibles ;
- collecte d’un fact minimal.

---

## 17. Nettoyage

Supprimer le fichier copié :

```bash
ansible all -i inventaire.ini -m file -a "path=/home/datascientest/test.txt state=absent"
```

S’assurer que Nginx est absent de `cible2` :

```bash
ansible cible2 -i inventaire.ini -b -m apt -a "name=nginx state=absent"
```

Supprimer le répertoire pédagogique éventuel :

```bash
ansible cible1 -i inventaire.ini -b -m file -a "path=/etc/datascientest state=absent"
```

---

## 18. Critères de réussite

Le lab est validé lorsque :

- [ ] les trois cibles répondent à `ping` ;
- [ ] `copy` fonctionne sur les trois cibles ;
- [ ] une deuxième exécution de `copy` illustre l’idempotence ;
- [ ] `setup` retourne des facts ;
- [ ] un filtre `setup` fonctionne ;
- [ ] `file` crée puis supprime un répertoire ;
- [ ] Nginx peut être installé sur `cible2` avec `-b` ;
- [ ] Nginx peut être supprimé ;
- [ ] la différence `command` / `shell` a été observée ;
- [ ] `ansible-doc` a été utilisé ;
- [ ] un cas `UNREACHABLE` a été diagnostiqué avec `-vvvv` ;
- [ ] `scripts/verify_lab.sh` termine avec succès après restauration d’un inventaire valide.

---

## 19. Suite

Le prochain lab approfondira l’élément que nous n’avons utilisé ici que sous sa forme la plus simple :

```text
l'inventaire Ansible
```

Suite du parcours :

```text
191.03_ANSIBLE_INVENTAIRES.md
labs/03-inventory/
```
