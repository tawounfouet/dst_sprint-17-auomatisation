# ANSIBLE_RESOURCE_INVENTORY_AND_MIGRATION_MAP

> **Projet :** DST — Sprint 17 — Automatisation  
> **Périmètre :** Ansible  
> **Dépôt cible :** `tawounfouet/dst_sprint-17-auomatisation`

## 1. Objectif

Ce document cartographie les ressources Ansible existantes avant leur intégration dans GitHub.

Il permet de répondre à cinq questions :

1. quelles ressources existent ;
2. quelle est leur origine ;
3. lesquelles sont canoniques, redondantes ou historiques ;
4. lesquelles nécessitent une sanitisation ;
5. quelle sera leur destination future dans `191 - Ansible DevOps/`.

La règle principale est la suivante : **ne pas importer le dossier local tel quel**. Les sources doivent d’abord être qualifiées, consolidées puis publiées sous une forme canonique.

---

# 2. Structure cible du Sprint 17

```text
dst_sprint-17-auomatisation/
├── .github/
├── 191 - Ansible DevOps/
└── 192 - Terraform DevOps/
```

La partie Ansible doit reprendre la logique déjà utilisée pour Terraform :

```text
cours numérotés
+
index
+
architecture/workflow
+
synthèse
+
labs
+
examen
+
projet final
```

---

# 3. Grandes familles de ressources observées

```text
Ansible/
├── cours-original/
├── cours_version-multipas/
├── examen/
├── guide/
├── images/
├── multipass-ansible-django-postgres/
├── resources/
├── archives/
├── _archives/
├── AGENTS.md
├── ansible.cfg
├── config.yaml
├── instance_state.py
├── Les Modules et les Commandes Adhoc.md
└── prompts.md
```

## Légende

| Marqueur | Signification |
|---|---|
| `KEEP` | conserver |
| `MERGE` | fusionner dans une ressource canonique |
| `SANITIZE` | retirer ou remplacer les secrets avant publication |
| `ARCHIVE` | conserver uniquement comme historique |
| `AUDIT` | contenu encore à examiner |

---

# 4. Cours originaux DataScientest

Ces fichiers constituent le **socle académique**.

| Ressource | Décision | Destination future |
|---|---|---|
| `cours-original/1. Introduction.md` | `MERGE + SANITIZE` | `191.01_ANSIBLE_INTRODUCTION_ET_INSTALLATION.md` |
| `cours-original/2. Ansible DevOps - Les modules et commandes ad hoc.md` | `MERGE` | `191.02_ANSIBLE_MODULES_ET_COMMANDES_AD_HOC.md` |
| `cours-original/3. Inventaire.md` | `MERGE` | `191.03_ANSIBLE_INVENTAIRES.md` |
| `cours-original/4. Playbook.md` | `MERGE` | `191.04_ANSIBLE_PLAYBOOKS.md` |
| `cours-original/5. Les Roles.md` | `MERGE` | `191.05_ANSIBLE_ROLES.md` |
| `cours-original/6. Vault.md` | `MERGE` | `191.06_ANSIBLE_VAULT.md` |
| `cours-original/7. Conclusion et Evaluation.md` | `MERGE` | `191.07_ANSIBLE_CONCLUSION_ET_PROJET_FINAL.md` + `Examen/` |

Ces fichiers ne doivent pas devenir directement la documentation active du dépôt.

---

# 5. Version enrichie Multipass

Cette famille modernise le cours en remplaçant le setup AWS par un environnement local reproductible basé sur Multipass et Ubuntu 24.04.

```text
cours_version-multipas/
├── I-1. multipass_setup-ansible.md
├── I-2. Installation-ansible-linux.md
├── I-3. Architecture Ansible.md
├── I-4. Le fichier de configuration.md
├── II - Les Modules et Commandes Adhoc.md
├── III - Inventaire.md
├── IV - Playbook.md
├── V - Roles.md
├── VI - Vault.md
└── VII - Conclusion et Evaluation.md
```

### Apports principaux

- Multipass ;
- Ubuntu 24.04 ;
- quatre VMs locales ;
- SSH et authentification par clé ;
- checklists de prérequis ;
- troubleshooting réel ;
- `ansible.cfg` par projet ;
- inventaires `dev` / `test` / `prod` ;
- `group_vars` / `host_vars` ;
- tests et sorties attendues ;
- corrections de problèmes rencontrés pendant les TPs.

### Mapping

| Source Multipass | Décision | Destination |
|---|---|---|
| `I-1. multipass_setup-ansible.md` | `KEEP + MERGE` | `191.01` + `labs/01-multipass-bootstrap/` |
| `I-2. Installation-ansible-linux.md` | `MERGE` | `191.01` |
| `I-3. Architecture Ansible.md` | `MERGE` | `191_ANSIBLE_ARCHITECTURE_AND_WORKFLOW.md` |
| `I-4. Le fichier de configuration.md` | `MERGE` | `191.01` + référence de configuration |
| `II - Les Modules et Commandes Adhoc.md` | `MERGE` | `191.02` + lab 02 |
| `III - Inventaire.md` | `MERGE` | `191.03` + lab 03 |
| `IV - Playbook.md` | `MERGE` | `191.04` + lab 04 |
| `V - Roles.md` | `MERGE` | `191.05` + lab 05 |
| `VI - Vault.md` | `MERGE` | `191.06` + lab 06 |
| `VII - Conclusion et Evaluation.md` | `MERGE` | `191.07` |

La version Multipass constitue la **source pratique principale**. Le cours original reste la référence pour le cadrage académique.

---

# 6. Fichiers techniques

## `config.yaml`

Type : cloud-init Multipass.

Rôle :

- créer l’utilisateur de formation ;
- configurer `sudo` ;
- initialiser l’accès SSH.

Décision :

```text
KEEP + SANITIZE
```

Destination :

```text
labs/01-multipass-bootstrap/config.yaml
```

Les mots de passe codés en dur doivent être remplacés avant publication.

## `instance_state.py`

Type : script Python pédagogique.

Rôle : interroger `multipass list --format json` pour reproduire localement la visibilité auparavant fournie par AWS/Boto3.

Décision :

```text
KEEP
```

Destination :

```text
labs/01-multipass-bootstrap/scripts/instance_state.py
```

## `ansible.cfg`

Deux usages sont à distinguer :

1. fichier de référence largement commenté ;
2. configuration minimale de lab.

La version de lab devra rester très courte, par exemple :

```ini
[defaults]
host_key_checking = False
interpreter_python = auto_silent
```

Décision pour la version historique :

```text
ARCHIVE / REFERENCE
```

## `Les Modules et les Commandes Adhoc.md`

Ce fichier recouvre le même domaine que le cours original et la version Multipass.

Décision :

```text
AUDIT → MERGE ou ARCHIVE
```

## `prompts.md`

Trace de conception utilisée pour demander un futur manuel de retour d’expérience.

Décision :

```text
ARCHIVE
```

Destination possible :

```text
archive/history/prompts.md
```

---

# 7. Assets graphiques

## Assets génériques

```text
ansible.png
architectures.png
```

Destination :

```text
resources/images/core/
```

## Assets du setup AWS historique

```text
aws_api.jpg
config_ec2_1.png
config_ec2.png
ec2_ip_public.jpg
ec2_type_t3_micro.png
user_data.png
```

Destination :

```text
resources/images/original-aws/
```

Ils doivent être conservés comme historique pédagogique, sans être confondus avec le parcours Multipass actif.

---

# 8. Répertoires encore à auditer

## P0 — priorité élevée

```text
multipass-ansible-django-postgres/
examen/
guide/
resources/
```

Le dossier `multipass-ansible-django-postgres/` est prioritaire car il peut contenir :

- l’implémentation réelle du projet ;
- les inventaires finaux ;
- les rôles ;
- les playbooks ;
- les tests ;
- les logs ;
- des preuves d’exécution.

Sa destination probable est :

```text
Projet_Final/
```

mais uniquement après audit et sanitisation.

## P1

```text
archives/
_archives/
AGENTS.md
```

Les deux dossiers d’archives devront être consolidés plus tard.

---

# 9. Mapping canonique des chapitres

| Cours original | Version enrichie | Document canonique |
|---|---|---|
| `1. Introduction.md` | `I-1` + `I-2` + `I-3` + `I-4` | `191.01_ANSIBLE_INTRODUCTION_ET_INSTALLATION.md` |
| `2. ...modules et commandes ad hoc.md` | `II - ...` | `191.02_ANSIBLE_MODULES_ET_COMMANDES_AD_HOC.md` |
| `3. Inventaire.md` | `III - Inventaire.md` | `191.03_ANSIBLE_INVENTAIRES.md` |
| `4. Playbook.md` | `IV - Playbook.md` | `191.04_ANSIBLE_PLAYBOOKS.md` |
| `5. Les Roles.md` | `V - Roles.md` | `191.05_ANSIBLE_ROLES.md` |
| `6. Vault.md` | `VI - Vault.md` | `191.06_ANSIBLE_VAULT.md` |
| `7. Conclusion et Evaluation.md` | `VII - ...` | `191.07_ANSIBLE_CONCLUSION_ET_PROJET_FINAL.md` |

---

# 10. Structure cible GitHub

```text
191 - Ansible DevOps/
├── README.md
├── .gitignore
├── 191.01_ANSIBLE_INTRODUCTION_ET_INSTALLATION.md
├── 191.02_ANSIBLE_MODULES_ET_COMMANDES_AD_HOC.md
├── 191.03_ANSIBLE_INVENTAIRES.md
├── 191.04_ANSIBLE_PLAYBOOKS.md
├── 191.05_ANSIBLE_ROLES.md
├── 191.06_ANSIBLE_VAULT.md
├── 191.07_ANSIBLE_CONCLUSION_ET_PROJET_FINAL.md
├── 191_ANSIBLE_INDEX.md
├── 191_ANSIBLE_ARCHITECTURE_AND_WORKFLOW.md
├── 191_ANSIBLE_SYNTHESE_COMPLETE.md
├── references/
├── labs/
│   ├── 01-multipass-bootstrap/
│   ├── 02-modules-ad-hoc/
│   ├── 03-inventory/
│   ├── 04-playbooks/
│   ├── 05-roles-wordpress/
│   └── 06-vault/
├── Examen/
├── Projet_Final/
├── resources/
└── archive/
```

---

# 11. Stratégie de consolidation

Pour chaque chapitre :

```text
cours-original
      +
version Multipass
      +
outputs / scripts / REX
      ↓
qualification
      ↓
normalisation
      ↓
sanitisation
      ↓
191.xx canonique
```

Aucune source ne doit être supprimée avant la fin de la comparaison et de la migration.

---

# 12. Politique de sécurité

Le dépôt cible est public.

Ne jamais versionner :

```text
*.pem
*.key
id_rsa
id_ed25519
.env
.vault_pass
AWS credentials réels
API tokens
private keys
secrets applicatifs
```

Les supports originaux doivent être contrôlés avant publication, notamment lorsqu’ils contiennent des identifiants pédagogiques ou historiques en clair.

Les exemples publics doivent utiliser :

```text
CHANGE_ME
<REDACTED>
<YOUR_IP>
<YOUR_KEY_PATH>
```

---

# 13. Plan de migration

## Phase 0 — Inventaire

- [x] identifier les grandes familles ;
- [x] identifier les cours originaux ;
- [x] identifier les cours Multipass ;
- [x] identifier les fichiers techniques ;
- [x] identifier les images ;
- [ ] auditer le projet réel ;
- [ ] auditer l’examen ;
- [ ] auditer les guides ;
- [ ] auditer les ressources ;
- [ ] auditer les archives.

## Phase 1 — Bootstrap GitHub

- [x] définir la structure cible ;
- [x] créer `191 - Ansible DevOps/` ;
- [x] créer le README ;
- [x] créer le `.gitignore` ;
- [x] créer l’index initial ;
- [x] versionner cette cartographie de migration.

## Phase 2 — Lab Multipass

Créer le premier environnement reproductible dans :

```text
labs/01-multipass-bootstrap/
```

## Phase 3 — Consolidation pédagogique

Produire progressivement :

```text
191.01 → 191.07
```

## Phase 4 — Projet final et examen

Auditer, sanitiser puis migrer les artefacts réellement exécutés.

## Phase 5 — Synthèses et références

Créer les documents transverses après stabilisation des chapitres canoniques.

---

# 14. Critères de réussite

La migration sera considérée aboutie lorsque :

- [ ] aucun secret réel n’est présent ;
- [ ] les sept chapitres sont consolidés ;
- [ ] les doublons sont identifiés ;
- [ ] le cursus original reste traçable ;
- [ ] les enrichissements Multipass sont préservés ;
- [ ] les labs sont reproductibles ;
- [ ] l’examen est isolé du cours ;
- [ ] le projet final possède sa documentation et ses preuves ;
- [ ] la structure est homogène avec Terraform ;
- [ ] `191_ANSIBLE_INDEX.md` permet de naviguer dans tout le corpus.

---

# 15. Décision d’architecture

La cible retenue est :

```text
dst_sprint-17-auomatisation/
├── 191 - Ansible DevOps/
└── 192 - Terraform DevOps/
```

La valeur du futur corpus Ansible repose sur trois couches complémentaires :

```text
THÉORIE
Cours DataScientest
      ↓
PRATIQUE
Multipass + Ubuntu 24.04
      ↓
EXPÉRIENCE
Debugging + projet réellement exécuté
```

Le dépôt public doit exposer la documentation canonique et les artefacts reproductibles, tout en conservant les sources historiques dans des espaces clairement identifiés et sanitizés.
