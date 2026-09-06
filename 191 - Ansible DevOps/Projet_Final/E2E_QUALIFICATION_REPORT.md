# Qualification réelle end-to-end — Projet final Ansible

> **Statut : QUALIFIÉ ✅**  
> **Date de qualification : 2026-09-06**  
> **Branche :** `feat/ansible-step-11-e2e-qualification`  
> **Workflow :** `.github/workflows/ansible-final-exam-e2e.yml`  
> **GitHub Actions run :** `34037316103`

---

## 1. Objectif

Ce rapport fige la preuve de qualification end-to-end du projet final Ansible issu de l'évaluation DataScientest.

L'objectif n'est pas uniquement de vérifier la syntaxe des playbooks, mais de démontrer qu'Ansible est capable de construire une architecture applicative complète, de la configurer, de la valider et de la rejouer sans modification résiduelle.

Le scénario qualifié couvre :

- deux systèmes Ubuntu 24.04 distincts ;
- un serveur Web `web1` ;
- un serveur de base de données `db1` ;
- Apache + PHP + PrestaShop sur le tier Web ;
- MySQL sur le tier Database ;
- communication TCP Web → Database ;
- authentification SQL avec un compte applicatif dédié ;
- installation réelle de PrestaShop ;
- exposition HTTP de l'application ;
- gestion des secrets via Ansible Vault ;
- deuxième exécution Ansible pour vérifier l'idempotence ;
- génération du ZIP final de l'examen et de son SHA-256.

---

## 2. Architecture qualifiée

```text
                    GitHub Actions
                          │
                          │ Ansible
                          ▼
                ┌──────────────────┐
                │  Control Node    │
                │ Ubuntu 24.04     │
                └────────┬─────────┘
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
        ┌──────────┐            ┌──────────┐
        │   web1   │            │   db1    │
        │ Ubuntu   │            │ Ubuntu   │
        │ 24.04    │            │ 24.04    │
        ├──────────┤            ├──────────┤
        │ Apache   │            │ MySQL    │
        │ PHP      │            │ :3306    │
        │PrestaShop│            │ DB + user│
        └────┬─────┘            └────▲─────┘
             │                       │
             └────── SQL/TCP ────────┘
                       ✅

        Control Node ── HTTP :80 ──► web1
                              ✅
```

Les cibles de qualification sont exécutées comme deux environnements Ubuntu 24.04 isolés disposant de `systemd`. Le transport `community.docker.docker` est utilisé par Ansible dans GitHub Actions afin de rendre cette qualification reproductible sans dépendre d'une infrastructure cloud permanente.

Cette qualification CI complète les laboratoires SSH/Multipass du sprint ; elle ne prétend pas constituer à elle seule une qualification d'un serveur public de production.

---

## 3. Environnement de qualification

| Élément | Valeur qualifiée |
|---|---|
| Runner | Ubuntu 24.04 |
| Python | 3.12.14 |
| Ansible Core | 2.20.8 |
| Cible Web | Ubuntu 24.04 / `web1` |
| Cible DB | Ubuntu 24.04 / `db1` |
| Transport CI | `community.docker.docker` |
| Collection Docker | `community.docker` 5.2.2 |
| Collection MySQL utilisée | `community.mysql` 4.3.0 |
| Application | PrestaShop |
| Serveur HTTP | Apache |
| Base de données | MySQL |

Le run a également signalé la dépréciation de `community.mysql.mysql_db` et `community.mysql.mysql_user` au profit de la collection `ansible.mysql`. Ce point est conservé comme dette de modernisation ; il n'a pas empêché la qualification fonctionnelle.

---

## 4. Chaîne de qualification

```text
Checkout repository
        │
        ▼
Install Ansible + collections
        │
        ▼
Provision web1 + db1
        │
        ▼
Generate ephemeral secrets
        │
        ▼
Encrypt vault.yml
        │
        ▼
Preflight
 inventory + ping + syntax
        │
        ▼
First deployment
        │
        ▼
Runtime validation
        │
        ▼
HTTP validation
        │
        ▼
Second deployment
        │
        ▼
Idempotence check
 changed=0
        │
        ▼
Package exam
        │
        ▼
SHA-256 + evidence artifact
```

---

## 5. Préflight

Le préflight a validé l'inventaire et la connectivité des deux cibles :

```text
@all:
  |--@web:
  |  |--web1
  |--@database:
     |--db1
```

Résultat Ansible :

```text
web1 | SUCCESS => ping: pong
db1  | SUCCESS => ping: pong
```

Le `syntax-check` de `playbooks/site.yml` a également terminé sans erreur.

**Verdict préflight : PASS ✅**

---

## 6. Premier déploiement

### Database tier

Le rôle MySQL a réellement :

- installé MySQL et le driver Python ;
- configuré l'écoute réseau ;
- démarré et activé MySQL ;
- exécuté le handler de redémarrage ;
- créé la base PrestaShop ;
- créé l'utilisateur applicatif avec privilèges limités.

Résultat :

```text
db1 : ok=7 changed=6 unreachable=0 failed=0
```

### Web tier

Le rôle PrestaShop a réellement :

- installé Apache, PHP, le client MySQL et les outils d'archive ;
- activé `mod_rewrite` ;
- préparé le répertoire d'installation ;
- téléchargé le paquet officiel PrestaShop ;
- extrait le paquet et son archive applicative imbriquée ;
- installé le VirtualHost Apache ;
- désactivé le site Apache par défaut ;
- activé le site PrestaShop ;
- redémarré Apache ;
- attendu la disponibilité de MySQL ;
- exécuté l'installateur CLI PrestaShop ;
- supprimé le répertoire d'installation après succès ;
- appliqué les permissions attendues.

Résultat :

```text
web1 : ok=20 changed=14 unreachable=0 failed=0 skipped=2
```

**Verdict déploiement initial : PASS ✅**

---

## 7. Validation runtime

Le playbook `playbooks/validate.yml` a validé le système après déploiement.

### Database

```text
MySQL service                 ✅
MySQL listening port          ✅
```

### Web et communication inter-tiers

```text
Apache service                ✅
web1 → db1 TCP connectivity   ✅
SQL authentication            ✅
HTTP endpoint local           ✅
```

Résultat :

```text
db1  : ok=2 changed=0 unreachable=0 failed=0
web1 : ok=4 changed=0 unreachable=0 failed=0
```

**Verdict runtime : PASS ✅**

---

## 8. Validation HTTP depuis le control node

Le workflow a ensuite interrogé PrestaShop depuis le runner, et non uniquement depuis `web1`.

Le conteneur Web a été résolu sur le réseau de qualification puis interrogé sur le port HTTP.

Résultat :

```text
web1 IP: 172.18.0.2
HTTP bytes: 88446
```

La commande `curl --fail` a terminé avec succès et le document retourné n'était pas vide.

**Verdict HTTP end-to-end : PASS ✅**

---

## 9. Qualification de l'idempotence

Le même déploiement a été exécuté une seconde fois sur les mêmes systèmes sans reconstruction des cibles.

Résultat :

```text
db1  : ok=6  changed=0 unreachable=0 failed=0
web1 : ok=12 changed=0 unreachable=0 failed=0 skipped=9
```

Le workflow vérifie explicitement qu'aucun `changed=[1-9][0-9]*` n'est présent dans le log de la seconde exécution.

Cela démontre que l'état convergé est stable : une nouvelle exécution n'entraîne pas de changement inutile.

**Verdict idempotence : PASS ✅**

---

## 10. Qualification des secrets

Pour le run CI, les secrets nécessaires sont générés dynamiquement :

```text
DB_PASSWORD      → aléatoire
ADMIN_PASSWORD   → aléatoire
VAULT_PASSWORD   → aléatoire
```

Ils sont injectés dans un `vault.yml` temporaire, puis ce fichier est chiffré avec `ansible-vault`.

Le fichier contenant le mot de passe Vault est stocké dans l'espace temporaire du runner avec des permissions `0600`.

Aucun secret réel de production n'est nécessaire au workflow.

**Verdict gestion des secrets CI : PASS ✅**

---

## 11. Packaging final

Le script :

```text
scripts/package_exam.sh
```

a généré avec succès :

```text
exam-final-ansible-20260906-135432.zip
```

SHA-256 du package :

```text
034bc6f7d1705cc94924c1c0263cd0cb572f71252282f8f00be70b55e6b9d058
```

Le ZIP contient notamment :

```text
inventories/
roles/mysql/
roles/prestashop/
playbooks/site.yml
playbooks/validate.yml
scripts/
tests/
ansible.cfg
requirements.yml
.gitignore
```

Les fichiers runtime contenant les secrets générés ne sont pas inclus comme secrets portables du livrable ; les exemples d'inventaire et de Vault sont utilisés pour rendre le package réutilisable.

**Verdict packaging : PASS ✅**

---

## 12. Evidence GitHub Actions

Run qualifié :

```text
GitHub Actions run ID : 34037316103
```

Artifact produit :

```text
ansible-final-exam-e2e-evidence
Artifact ID: 9990631319
```

Le workflow a uploadé six fichiers de preuve issus de :

```text
Projet_Final/evidence/logs/*.txt
Projet_Final/evidence/validation/*.sha256
Projet_Final/ansible-project/exam-final-ansible-*.zip
```

Digest SHA-256 de l'archive GitHub Actions elle-même :

```text
6762dde9e02047f0e61d46c354bb3b05bdae926c319bba8d244ce2328854fca6
```

---

## 13. Incidents rencontrés et root causes

La qualification réelle a révélé des problèmes qui n'étaient pas visibles avec un simple contrôle statique.

### 13.1 Initialisation de systemd

**Symptôme**

Les premières cibles de test n'étaient pas suffisamment proches d'un vrai hôte Ubuntu pour valider correctement les services.

**Cause**

Un rôle qui manipule Apache/MySQL avec `systemd` doit être testé dans un environnement où l'init system est réellement disponible.

**Correction**

Utilisation de cibles Ubuntu 24.04 adaptées à Ansible et lancées avec les capacités nécessaires à `systemd`.

**Leçon**

Un test de syntaxe ou un conteneur minimal ne suffit pas à qualifier un rôle système.

### 13.2 Chargement de `vault.yml`

**Symptôme**

Les variables Vault n'étaient pas disponibles comme attendu pendant une itération de qualification.

**Cause**

Le fichier Vault nécessitait un chargement explicite dans le scénario retenu.

**Correction**

Chargement explicite via `vars_files` dans le playbook concerné.

**Leçon**

Ne pas confondre chiffrement d'un fichier et mécanisme de découverte/chargement de ses variables.

### 13.3 Redirection HTTP PrestaShop

**Symptôme**

La validation HTTP externe pouvait suivre une redirection vers le hostname configuré par PrestaShop.

**Cause**

PrestaShop connaît son hostname applicatif et peut produire une redirection canonique.

**Correction**

Le test externe utilise une résolution contrôlée du hostname `web1` vers l'adresse de la cible Web.

**Leçon**

Une validation HTTP end-to-end doit tester le comportement applicatif réel, redirections comprises, et pas uniquement l'ouverture du port 80.

---

## 14. Dette technique observée

La qualification est verte, mais le run signale :

```text
community.mysql.mysql_db   → deprecated
community.mysql.mysql_user → deprecated
```

La migration vers la collection `ansible.mysql` constitue donc une amélioration recommandée avant une future montée majeure de collection.

Ce warning n'invalide pas le run actuel : aucune tâche n'a échoué.

---

## 15. Matrice finale de qualification

| Contrôle | Résultat |
|---|---:|
| Inventaire Ansible | ✅ |
| Connectivité `web1` | ✅ |
| Connectivité `db1` | ✅ |
| Syntaxe playbook | ✅ |
| Installation MySQL | ✅ |
| Démarrage MySQL | ✅ |
| Base PrestaShop | ✅ |
| Compte SQL applicatif | ✅ |
| Installation Apache/PHP | ✅ |
| Installation PrestaShop | ✅ |
| Apache actif | ✅ |
| Web → DB TCP | ✅ |
| Authentification SQL | ✅ |
| HTTP local | ✅ |
| HTTP depuis control node | ✅ |
| Ansible Vault | ✅ |
| Aucun secret réel requis en CI | ✅ |
| Deuxième run | ✅ |
| `changed=0` deuxième run | ✅ |
| Packaging ZIP | ✅ |
| SHA-256 | ✅ |
| Artifact de preuves | ✅ |

---

## 16. Périmètre de la preuve

Il est important de distinguer trois niveaux :

```text
Laboratoires Multipass
        │
        ├── SSH réel
        └── apprentissage / exercices

Qualification GitHub Actions E2E
        │
        ├── 2 Ubuntu 24.04
        ├── systemd réel
        ├── services réels
        ├── PrestaShop réel
        ├── MySQL réel
        ├── communication inter-tier réelle
        └── reproductibilité CI

Production publique
        │
        └── qualification infrastructure/cloud séparée
```

Ce rapport certifie le **deuxième niveau**.

Il ne doit pas être interprété comme la preuve qu'une adresse IP publique ou une infrastructure cloud externe donnée est actuellement en production.

---

## 17. Verdict final

La qualification démontre la chaîne complète :

```text
Infrastructure de test
        ↓
Inventaire
        ↓
Ansible
        ↓
Roles MySQL + PrestaShop
        ↓
Services systemd
        ↓
Base + utilisateur applicatif
        ↓
Communication Web → DB
        ↓
Installation applicative
        ↓
HTTP fonctionnel
        ↓
Validation runtime
        ↓
Deuxième exécution
        ↓
changed=0
        ↓
Packaging + SHA-256
        ↓
Evidence CI
```

### Décision

> **PROJET FINAL ANSIBLE — QUALIFICATION END-TO-END : PASS ✅**

Le projet n'est donc plus seulement un ensemble de playbooks cohérents ou syntaxiquement valides : le scénario complet a été exécuté avec succès sur deux systèmes Ubuntu distincts, l'application et la base ont communiqué réellement, le frontend HTTP a répondu, et le second passage a démontré l'idempotence.

---

## 18. Références de preuve

- Workflow : `.github/workflows/ansible-final-exam-e2e.yml`
- Playbook principal : `Projet_Final/ansible-project/playbooks/site.yml`
- Validation runtime : `Projet_Final/ansible-project/playbooks/validate.yml`
- Préflight : `Projet_Final/ansible-project/scripts/preflight.sh`
- Exécution : `Projet_Final/ansible-project/scripts/run_exam.sh`
- Validation : `Projet_Final/ansible-project/scripts/validate_runtime.sh`
- Packaging : `Projet_Final/ansible-project/scripts/package_exam.sh`
- Logs : `Projet_Final/evidence/logs/`
- Checksums : `Projet_Final/evidence/validation/`
- Run GitHub Actions qualifié : `34037316103`
- Artifact GitHub Actions : `9990631319`
