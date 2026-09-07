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
POST-CONVERGENCE FUNCTIONAL SMOKE                   ✅ GREEN
CI GREEN                                            ✅
```

DC-14 ne se contente pas de vérifier que Docker Compose fonctionne. Le jalon qualifie la **stabilité réelle d'une seconde convergence Ansible complète** sur une cible STG-like déjà conforme.

Le gate est désormais GREEN sur le commit applicatif testé `ec4be912013c625df6ea347c43c20cf650c66297`.

## Qualification canonique

```text
Workflow : Ansible Django PostgreSQL Redis Celery Compose Strict Idempotence
Run      : #5
Run ID   : 34149470184
Job ID   : 101828487085
Commit   : ec4be912013c625df6ea347c43c20cf650c66297
Result   : SUCCESS
Runner   : GitHub-hosted Ubuntu 24.04.4 LTS
Python   : 3.12.14
Ansible  : ansible-core 2.20.8
```

La première convergence a matérialisé l'état attendu :

```text
localhost : ok=54 changed=8 unreachable=0 failed=0 skipped=3
DC14_PASS1_PASS: first convergence changed=8
DC14_DATA_SEED_PASS: PostgreSQL, Redis and static-volume probes written
```

La seconde convergence, avec les mêmes entrées, a produit :

```text
localhost : ok=54 changed=0 unreachable=0 failed=0 skipped=3
DC14_ANSIBLE_PASS: second full site convergence changed=0
```

Puis l'ensemble des preuves fortes a été observé :

```text
DC14_CONTAINER_PASS
DC14_VOLUME_PASS
DC14_CONFIG_PASS
DC14_ARTIFACT_PASS
DC14_DATA_PASS
DC14_FUNCTIONAL_PASS
DC14_COMPOSE_EQUIVALENCE
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
  → données persistantes inchangées
```

Pour Docker Compose, la notion est précisée : les six conteneurs long-running `nginx`, `web`, `db`, `redis`, `worker`, `beat` ne doivent pas être recréés. Les commandes administratives 12-Factor exécutées via `docker compose run --rm` restent volontairement des processus one-shot éphémères ; elles sont acceptées uniquement si leur seconde exécution ne modifie aucun état et si Ansible les comptabilise `changed=false`.

## Préparation de la cible

Le gate utilise un runner Ubuntu 24.04 éphémère et prépare d'abord le socle hôte avec les rôles actifs :

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

## STG sans build ni pull implicite

DC-14 aligne le rôle `compose_stack` sur la politique déjà qualifiée dans DC-13 :

```text
DEV      → pull policy Compose native
STG/PROD → pull=never
STG/PROD → build=never
```

Une image applicative STG/PROD reste obligatoire sous forme :

```text
registry/path/image@sha256:<64 hex>
```

Ainsi, si l'une des deux convergences essayait de reconstruire ou de récupérer l'image applicative depuis le registry de promotion déjà supprimé, elle échouerait.

Dans le run canonique, l'image a été construite et promue **une seule fois avant la paire**, puis son identité et son horodatage de création sont restés inchangés jusqu'à la fin du gate.

## Correction healthcheck STG/PROD

La qualification Ansible réelle a aussi fait apparaître une contrainte de runtime : les healthchecks du conteneur `web` interrogent `127.0.0.1:8000`. Les inventaires STG/PROD incluent donc explicitement :

```text
localhost
127.0.0.1
```

parmi `DJANGO_ALLOWED_HOSTS`, en plus des noms DNS métier et des noms de services Compose.

Ce changement ne publie aucun port interne ; il autorise seulement la requête loopback effectuée **à l'intérieur du conteneur**.

## Preuves de non-recréation

Après la première convergence, le gate capture pour les six services :

```text
container ID
image ID
configured image reference
health state
```

Après la seconde convergence, les snapshots doivent être strictement identiques.

Le run canonique a confirmé :

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

Les checksums doivent rester identiques.

Le fichier `.env.runtime` reste `root:root 0600`, n'est jamais affiché, et seul son digest est comparé. Le run canonique a confirmé :

```text
DC14_CONFIG_PASS: Compose files, service configs and .env.runtime checksums are unchanged
```

## Preuves de conservation des volumes et données

Le gate capture les volumes nommés montés sur :

```text
db
redis
web / staticfiles
```

Il écrit ensuite trois sondes persistantes :

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

et exige les mêmes métadonnées après la seconde convergence.

Les trois processus applicatifs `web`, `worker`, `beat` continuent à pointer sur la même image préparée avant la paire. La preuve canonique est :

```text
DC14_ARTIFACT_PASS: application image identity/creation metadata unchanged; no rebuild occurred in the idempotence pair
```

## Validation fonctionnelle après convergence 2

Une seconde convergence parfaitement stable ne doit pas casser le service. Le gate réutilise donc la validation STG-like après le `changed=0` pour confirmer :

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

DC-14 a révélé trois écarts que les qualifications fonctionnelles précédentes ne suffisaient pas à exposer.

### 1. Projet Compose différent pour les one-off

Les commandes `docker compose run --rm` utilisaient initialement le nom de projet implicite du répertoire alors que `community.docker.docker_compose_v2` utilisait explicitement `datascientest`. Les processus de migration pouvaient donc rejoindre un réseau Compose différent de celui de `db` et `redis`.

Correction : toutes les opérations one-shot utilisent désormais explicitement :

```text
--project-name datascientest
```

### 2. Lecture de `.env.runtime` par le harness

Le harness tentait initialement de lire `.env.runtime` comme utilisateur non privilégié, alors que DC-09 impose légitimement :

```text
root:root
0600
```

La correction a porté sur le **test**, pas sur la sécurité : seules les opérations de contrôle qui doivent lire ce fichier passent par un contexte privilégié. Les permissions du secret n'ont pas été relâchées.

### 3. Drift de mode sur `redis/entrypoint.sh`

Le source Git du fichier `docker/redis/entrypoint.sh` est versionné en mode exécutable `100755`. Le déploiement récursif Ansible utilise `mode: preserve`, mais une tâche suivante forçait le fichier à `0555`.

Chaque nouvelle convergence provoquait donc le cycle :

```text
copy preserve : 0555 → 0755  => changed
file task     : 0755 → 0555  => changed
```

Le PASS 2 restait alors à `changed=2` malgré une stack fonctionnellement correcte.

Correction : le rôle converge désormais vers `0755`, cohérent avec le mode Git source. Le run canonique suivant a obtenu `changed=0`.

## Régressions sur le même commit qualifié

Le commit `ec4be912013c625df6ea347c43c20cf650c66297` a également passé les gates de régression suivants :

```text
Static Gate
Run ID 34149470178
Job ID 101828487082
SUCCESS

DEV Full E2E
Run ID 34149470187
Job ID 101828487313
SUCCESS

STG-like E2E
Run ID 34149470152
Job ID 101828486901
SUCCESS

Strict Idempotence
Run ID 34149470184
Job ID 101828487085
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

Il ne constitue pas encore une preuve de déploiement sur un VPS distant via SSH, ni une qualification de production réelle, de registry distant, de TLS public ou de haute disponibilité multi-hôte.

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
