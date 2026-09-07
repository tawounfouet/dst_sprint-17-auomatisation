# DC-14 — Strict Idempotence

## Statut

```text
IMPLEMENTATION                                      ✅
FULL ANSIBLE SITE PASS 1                           ✅ QUALIFIED
FULL ANSIBLE SITE PASS 2                           ✅ QUALIFIED
SECOND PASS changed=0                              ✅ GREEN
NO APPLICATION REBUILD IN IDEMPOTENCE PAIR         ✅ GREEN
NO LONG-RUNNING CONTAINER RECREATE                 ✅ GREEN
CONFIG CHECKSUM STABILITY                          ✅ GREEN
NAMED VOLUME ATTACHMENT STABILITY                  ✅ GREEN
POSTGRESQL DATA PRESERVATION                       ✅ GREEN
REDIS DATA PRESERVATION                            ✅ GREEN
STATIC VOLUME DATA PRESERVATION                    ✅ GREEN
POST-CONVERGENCE FUNCTIONAL SMOKE                  ✅ GREEN
CI GREEN                                            ✅
```

DC-14 qualifie la **stabilité réelle d'une seconde convergence Ansible complète** sur une cible STG-like déjà conforme. Le jalon ne se limite ni à `docker compose up`, ni au seul compteur `changed=0` : il corrèle l'idempotence Ansible avec l'identité des conteneurs, l'image applicative, les volumes, les checksums de configuration et les données persistantes.

## Qualification canonique

```text
Workflow : Ansible Django PostgreSQL Redis Celery Compose Strict Idempotence
Run      : #6
Run ID   : 34166358818
Job ID   : 101878054495
Commit   : 109d47d45b259967856a7c0aec5e571c8b80966d
Result   : SUCCESS
Runner   : GitHub-hosted Ubuntu 24.04.4 LTS
Python   : 3.12.14
Ansible  : ansible-core 2.20.8
Docker   : 28.0.4
```

Le runner expose initialement Docker Compose v2.38.2. Après qualification du rôle `docker_engine`, le paquet Docker officiel installé sur la cible de test rapporte Compose v5.5.1 et Buildx v0.37.0. Cette distinction est conservée pour ne pas confondre l'outillage préinstallé du runner avec celui réellement convergé par Ansible.

La première convergence a matérialisé l'état attendu :

```text
localhost : ok=53 changed=8 unreachable=0 failed=0 skipped=3
DC14_PASS1_PASS: first convergence changed=8
DC14_DATA_SEED_PASS: PostgreSQL, Redis and static-volume probes written
```

La seconde convergence, avec les mêmes entrées, a produit :

```text
localhost : ok=53 changed=0 unreachable=0 failed=0 skipped=3
DC14_ANSIBLE_PASS: second full site convergence changed=0
```

Puis l'ensemble des preuves fortes a été observé :

```text
DC14_CONTAINER_PASS: six long-running service container IDs and image IDs are unchanged
DC14_VOLUME_PASS: PostgreSQL, Redis and static named-volume attachments are unchanged
DC14_CONFIG_PASS: Compose files, service configs and .env.runtime checksums are unchanged
DC14_ARTIFACT_PASS: application image identity/creation metadata unchanged; no rebuild occurred in the idempotence pair
DC14_DATA_PASS: PostgreSQL, Redis and static-volume data survived pass 2
DC14_FUNCTIONAL_PASS: post-idempotence STG health, Celery round-trips and host-port contract remain valid
DC14_COMPOSE_EQUIVALENCE: runtime containers are stable; release/admin docker compose run --rm processes remain intentionally ephemeral but report changed=false when they make no state change
DC14_STRICT_IDEMPOTENCE_PASS
```

## Définition de l'idempotence stricte

La qualification retient le contrat suivant :

```text
Convergence 1
  → matérialise l'état cible
  → changed > 0 attendu

Convergence 2, mêmes entrées
  → Ansible failed=0
  → Ansible changed=0
  → mêmes six conteneurs runtime
  → même image applicative digest-pinned
  → mêmes volumes nommés
  → mêmes checksums de configuration déployée
  → données persistantes préservées
  → service toujours fonctionnel
```

Pour Docker Compose, les six conteneurs long-running `nginx`, `web`, `db`, `redis`, `worker`, `beat` ne doivent pas être recréés. Les commandes administratives 12-Factor exécutées via `docker compose run --rm` restent volontairement des processus one-shot éphémères ; elles sont acceptées uniquement si leur seconde exécution ne modifie aucun état et si Ansible les comptabilise `changed=false`.

## Préparation de la cible

Le gate utilise un runner Ubuntu 24.04 éphémère et prépare d'abord le socle hôte avec :

```text
common
docker_engine
docker_runtime_hardening
```

Cette phase est hors de la paire d'idempotence applicative afin que l'image immuable soit construite **après** stabilisation du Docker Engine et de sa configuration.

Ensuite, hors Compose :

```text
postgres:16-alpine → preload
redis:7.4-alpine   → preload
nginx:1.27-alpine  → preload
application image  → build unique + promotion repository@sha256
```

Le registry localhost éphémère utilisé pour obtenir le digest applicatif est supprimé avant la paire de convergences.

Le digest applicatif observé dans le run canonique est :

```text
sha256:237a30e9349bcee697889f382d42a495287cdce6bcd0b001710f7edd2d42c467
```

## STG sans build ni pull implicite

DC-14 conserve la politique qualifiée dans DC-13 :

```text
DEV      → politique Compose de développement
STG/PROD → pull=never
STG/PROD → build=never
```

Une image applicative STG/PROD reste obligatoire sous forme :

```text
registry/path/image@sha256:<64 hex>
```

Ainsi, si l'une des deux convergences essayait de reconstruire ou de récupérer l'image applicative depuis le registry de promotion déjà supprimé, elle échouerait.

## Preuves de non-recréation

Après la première convergence, le gate capture pour les six services :

```text
container ID
image ID
configured image reference
health state
```

Après la seconde convergence, les snapshots doivent être strictement identiques. Le run canonique confirme :

```text
DC14_CONTAINER_PASS: six long-running service container IDs and image IDs are unchanged
```

Cette preuve est plus forte qu'un simple `docker compose ps` : un conteneur recréé avec le même nom et la même image posséderait un nouvel ID et ferait échouer le gate.

## Preuves de stabilité de configuration

Les checksums SHA-256 suivants sont capturés avant et après la seconde convergence :

```text
compose.yml
compose.stg.yml
nginx/default.conf
redis/entrypoint.sh
.env.runtime
```

Le fichier `.env.runtime` reste `root:root 0600`, n'est jamais affiché, et seul son digest est comparé.

```text
DC14_CONFIG_PASS: Compose files, service configs and .env.runtime checksums are unchanged
```

## Preuves de conservation des volumes et données

Le gate capture les volumes nommés montés sur `db`, `redis` et `web/staticfiles`, puis écrit trois sondes persistantes :

```text
PostgreSQL → table dc14_idempotence_probe, marker=preserved
Redis      → clé dc14:idempotence=preserved + SAVE
static     → /app/staticfiles/.dc14-idempotence
```

Après la seconde convergence, les mêmes volumes sont toujours attachés et les trois sondes sont relues avec succès :

```text
DC14_VOLUME_PASS: PostgreSQL, Redis and static named-volume attachments are unchanged
DC14_DATA_PASS: PostgreSQL, Redis and static-volume data survived pass 2
```

## Preuve d'absence de rebuild

Le gate capture avant la paire :

```text
image ID
image Created timestamp
repository@sha256
```

et exige les mêmes métadonnées après la seconde convergence. `web`, `worker` et `beat` continuent à pointer sur la même image préparée avant la paire.

```text
DC14_ARTIFACT_PASS: application image identity/creation metadata unchanged; no rebuild occurred in the idempotence pair
```

## Validation fonctionnelle après convergence 2

Une convergence stable ne doit pas casser le service. Le gate réutilise donc la validation STG-like après le `changed=0` pour confirmer :

```text
health database / redis / celery
add(21,21) → 42
uppercase(datascientest) → DATASCIENTEST
database_probe → SELECT 1
port public Nginx accessible
8000 / 5432 / 6379 non accessibles depuis l'hôte
```

Le run canonique conclut :

```text
DC14_FUNCTIONAL_PASS: post-idempotence STG health, Celery round-trips and host-port contract remain valid
```

## Root causes découvertes par DC-14

DC-14 a révélé plusieurs écarts qu'une simple qualification fonctionnelle ne suffisait pas à exposer.

### 1. Projet Compose différent pour les one-off

Les commandes `docker compose run --rm` utilisaient initialement le nom de projet implicite du répertoire alors que `community.docker.docker_compose_v2` utilisait explicitement `datascientest`. Les processus de migration pouvaient donc rejoindre un réseau Compose différent de celui de `db` et `redis`.

Correction : toutes les opérations one-shot utilisent explicitement :

```text
--project-name datascientest
```

### 2. Lecture de `.env.runtime` par le harness

Le harness tentait initialement de lire `.env.runtime` comme utilisateur non privilégié, alors que DC-09 impose légitimement :

```text
root:root
0600
```

La correction a porté sur le **test**, pas sur la sécurité : seules les opérations de contrôle devant lire ce fichier sont exécutées avec les privilèges nécessaires. Les permissions du secret n'ont pas été relâchées.

### 3. Oscillation de mode sur `redis/entrypoint.sh`

Le déploiement récursif Ansible conservait le mode du fichier source puis une tâche supplémentaire modifiait à nouveau explicitement son mode. À chaque convergence, les deux tâches pouvaient se répondre et produire un faux drift permanent :

```text
copy mode: preserve → changement de mode
file/chmod          → changement inverse
PASS 2              → changed=2
```

La correction finale évite complètement ce couplage :

```text
Compose Redis entrypoint → /bin/sh /usr/local/bin/datascientest-redis-entrypoint
Ansible                  → aucune tâche chmod dédiée après la copie récursive
```

Le script n'a donc plus besoin d'être rendu exécutable par une seconde tâche ; son contenu et son mode restent stables après la copie. Le run #6 obtient réellement `changed=0` sur la seconde convergence.

## Régressions sur le même commit qualifié

Le commit `109d47d45b259967856a7c0aec5e571c8b80966d` a passé simultanément les quatre gates :

```text
Static Gate
Run #17
Run ID 34166358846
SUCCESS

DEV Full E2E
Run #10
Run ID 34166358817
SUCCESS

STG-like E2E
Run #9
Run ID 34166358816
SUCCESS

Strict Idempotence
Run #6
Run ID 34166358818
Job ID 101878054495
SUCCESS
```

La correction d'idempotence ne régresse donc ni les contrôles statiques, ni le runtime DEV Full, ni la qualification STG-like.

## Harness

```text
ansible-project/tests/idempotence/run_strict_idempotence.sh
```

Workflow :

```text
.github/workflows/ansible-django-postgresql-redis-celery-docker-compose-idempotence.yml
```

Le script refuse par défaut de modifier un poste normal. Il exige soit un runner GitHub Actions, soit l'opt-in explicite :

```text
DC14_ALLOW_EPHEMERAL_HOST=1
```

car la qualification installe/configure Docker et modifie le firewall de l'hôte éphémère.

## Périmètre de la preuve

Le statut GREEN démontre une convergence réelle sur un **runner GitHub-hosted Ubuntu 24.04 éphémère**, avec Ansible exécuté localement sur cette cible de qualification.

Il ne constitue pas une preuve de déploiement sur un VPS distant via SSH, ni une qualification de production réelle, de registry distant, de TLS public ou de haute disponibilité multi-hôte.

## Verdict

```text
DC14_ANSIBLE_PASS: second full site convergence changed=0
DC14_CONTAINER_PASS
DC14_VOLUME_PASS
DC14_CONFIG_PASS
DC14_ARTIFACT_PASS
DC14_DATA_PASS
DC14_FUNCTIONAL_PASS
DC14_COMPOSE_EQUIVALENCE
DC14_STRICT_IDEMPOTENCE_PASS

DC-14 STRICT IDEMPOTENCE = GREEN
```

## Prochain jalon

```text
DC-15 — Package + SHA-256 + artifact
```
