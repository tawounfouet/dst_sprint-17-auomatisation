# Lab 03 — Inventaire Ansible structuré

Ce laboratoire reprend le cas pratique DataScientest consacré aux inventaires et l’adapte à l’infrastructure Multipass mise en place dans les labs précédents.

## Objectifs

À la fin du lab, vous devez avoir :

```text
datascientest_app
├── dev
│   └── client-dev
├── test
│   └── client-test
└── prod
    └── client-prod
```

avec une variable `env` propre à chaque groupe et une authentification SSH par clé.

## Prérequis

- Lab 01 terminé ;
- Lab 02 terminé ;
- `ansible-master`, `cible1`, `cible2`, `cible3` démarrées ;
- clé SSH de `datascientest` fonctionnelle vers les trois cibles.

Depuis l’hôte macOS :

```bash
multipass list
```

Puis entrez dans le master :

```bash
multipass shell ansible-master
su - datascientest
```

## 1. Récupérer les IPs

Ne copiez pas les IPs d’un exemple. Utilisez :

```bash
multipass list
```

Mappez ensuite :

```text
cible1 → client-dev
cible2 → client-test
cible3 → client-prod
```

## 2. Préparer l’inventaire INI

Copiez l’exemple :

```bash
cp inventaire.example.ini inventaire.ini
```

Remplacez :

```text
<IP_CIBLE1>
<IP_CIBLE2>
<IP_CIBLE3>
```

par les valeurs réelles.

Le fichier obtenu doit ressembler à :

```ini
[dev]
client-dev ansible_host=<IP_CIBLE1>

[test]
client-test ansible_host=<IP_CIBLE2>

[prod]
client-prod ansible_host=<IP_CIBLE3>

[dev:vars]
env=dev

[test:vars]
env=test

[prod:vars]
env=prod

[datascientest_app:children]
dev
test
prod

[all:vars]
ansible_user=datascientest
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

## 3. Inspecter avant exécution

```bash
ansible-inventory -i inventaire.ini --list
ansible-inventory -i inventaire.ini --graph
```

Résultat graphique attendu :

```text
@all:
  |--@datascientest_app:
  |  |--@dev:
  |  |  |--client-dev
  |  |--@test:
  |  |  |--client-test
  |  |--@prod:
  |  |  |--client-prod
  |--@ungrouped:
```

Le support Multipass enrichi rapporte qu’une mauvaise interprétation des sections de variables avait été diagnostiquée en observant `--graph`. Dans ce lab, nous conservons l’ordre de sections utilisé dans la version du TP qui fonctionnait, avec `[all:vars]` à la fin.

## 4. Tester le ciblage

Tous les hôtes :

```bash
ansible all -i inventaire.ini -m ping
```

Un groupe :

```bash
ansible dev -i inventaire.ini -m ping
```

Un seul hôte :

```bash
ansible client-prod -i inventaire.ini -m ping
```

Le groupe parent :

```bash
ansible datascientest_app -i inventaire.ini -m ping
```

## 5. Tester les variables `env`

```bash
ansible-inventory -i inventaire.ini --host client-dev
ansible-inventory -i inventaire.ini --host client-test
ansible-inventory -i inventaire.ini --host client-prod
```

Vous devez retrouver respectivement :

```text
env=dev
env=test
env=prod
```

## 6. Générer la représentation YAML

```bash
ansible-inventory -i inventaire.ini -y --list > inventaire.generated.yaml
```

Puis :

```bash
cat inventaire.generated.yaml
```

Le fichier `inventaire.example.yaml` fourni dans ce lab montre une structure YAML écrite manuellement avec les mêmes groupes.

## 7. Rejouer les modules du lab 02

### setup

```bash
ansible all -i inventaire.ini -m setup -a "filter=ansible_memtotal_mb"
```

### copy

```bash
echo "Inventaire Ansible DataScientest" > datascientest.txt
ansible all -i inventaire.ini \
  -m ansible.builtin.copy \
  -a "src=datascientest.txt dest=/home/datascientest/datascientest.txt"
```

### apt sur le groupe dev

```bash
ansible dev -i inventaire.ini -b \
  -m ansible.builtin.apt \
  -a "name=curl state=present update_cache=yes"
```

## 8. Variante structurée `group_vars` / `host_vars`

Le support du chapitre Playbook externalise ensuite les variables de groupe et d’hôte. Le sous-arbre `structured/` prépare cette organisation :

```text
structured/
├── hosts.yaml
├── group_vars/
│   ├── all.yaml
│   ├── dev.yaml
│   ├── test.yaml
│   └── prod.yaml
└── host_vars/
    ├── client-dev.yaml
    ├── client-test.yaml
    └── client-prod.yaml
```

Remplacez les placeholders dans `host_vars/`, puis testez :

```bash
ansible-inventory -i structured/hosts.yaml --graph
ansible all -i structured/hosts.yaml -m ping
```

## 9. Qualification automatisée

Le script fourni vérifie sans installer ni supprimer de paquet :

```bash
chmod +x scripts/verify_inventory.sh
./scripts/verify_inventory.sh
```

Il contrôle :

- présence d’Ansible ;
- parsing de l’inventaire ;
- structure graphique ;
- connectivité ;
- présence des trois alias.

## 10. Dépannage

### `UNREACHABLE`

```bash
ssh datascientest@<IP_CIBLE>
ansible client-dev -i inventaire.ini -m ping -vvvv
```

Vérifiez : IP, utilisateur, clé SSH et état de la VM.

### Un élément inattendu apparaît sous `ungrouped`

```bash
ansible-inventory -i inventaire.ini --graph
ansible-inventory -i inventaire.ini --list
```

Relisez ensuite les sections INI et leurs noms.

### Le mauvais `ansible.cfg` est utilisé

```bash
ansible --version
```

La ligne `config file` doit pointer vers le fichier attendu du lab.

## 11. Nettoyage

```bash
rm -f inventaire.ini inventaire.generated.yaml datascientest.txt
```

Le nettoyage ne supprime pas les VMs, car elles sont réutilisées dans le prochain lab.

## Résultat attendu

Le lab est validé lorsque :

```text
client-dev  → ping OK → env=dev
client-test → ping OK → env=test
client-prod → ping OK → env=prod
```

et que :

```bash
ansible-inventory -i inventaire.ini --graph
```

affiche correctement `datascientest_app` et ses trois groupes enfants.
