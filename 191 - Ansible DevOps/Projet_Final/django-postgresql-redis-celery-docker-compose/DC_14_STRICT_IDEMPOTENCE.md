# DC-14 — Strict Idempotence

## Statut

```text
IMPLEMENTATION                                      ✅
FULL ANSIBLE SITE PASS 1                           ✅ IMPLEMENTED
FULL ANSIBLE SITE PASS 2                           ✅ IMPLEMENTED
SECOND PASS changed=0                              ✅ IMPLEMENTED
NO APPLICATION REBUILD IN IDEMPOTENCE PAIR         ✅ IMPLEMENTED
NO LONG-RUNNING CONTAINER RECREATE                 ✅ IMPLEMENTED
CONFIG CHECKSUM STABILITY                          ✅ IMPLEMENTED
NAMED VOLUME ATTACHMENT STABILITY                  ✅ IMPLEMENTED
POSTGRESQL DATA PRESERVATION                       ✅ IMPLEMENTED
REDIS DATA PRESERVATION                            ✅ IMPLEMENTED
STATIC VOLUME DATA PRESERVATION                    ✅ IMPLEMENTED
POST-CONVERGENCE FUNCTIONAL SMOKE                   ✅ IMPLEMENTED
CI GREEN                                            ⏳
```

DC-14 ne se contente plus de vérifier que Docker Compose fonctionne. Le jalon qualifie la **stabilité d'une seconde convergence Ansible complète** sur une cible STG-like déjà conforme.

Aucun statut GREEN n'est revendiqué avant observation d'un run GitHub Actions réussi.

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

Ainsi, si la seconde convergence essayait de reconstruire ou de récupérer l'image applicative depuis le registry de promotion déjà supprimé, elle échouerait.

## Correction healthcheck STG/PROD

La qualification Ansible réelle fait aussi apparaître une contrainte de runtime : les healthchecks du conteneur `web` interrogent `127.0.0.1:8000`. Les inventaires STG/PROD incluent donc désormais explicitement :

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

Le fichier `.env.runtime` n'est jamais imprimé ; seul son digest est comparé.

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

Après la seconde convergence :

```text
mêmes volumes nommés
PostgreSQL marker=preserved
Redis marker=preserved
static marker=preserved
```

sont obligatoires.

## Preuve d'absence de rebuild

Le gate capture avant la paire :

```text
image ID
image Created timestamp
repository@sha256
```

et exige les mêmes métadonnées après la seconde convergence.

Les trois processus applicatifs `web`, `worker`, `beat` doivent continuer à pointer sur la même image préparée avant la paire.

## Validation fonctionnelle après convergence 2

Une seconde convergence parfaitement stable ne doit pas casser le service. Le gate réutilise donc la validation STG-like pour confirmer après `changed=0` :

```text
health database / redis / celery
add(21,21) → 42
uppercase(datascientest) → DATASCIENTEST
database_probe → SELECT 1
port public Nginx accessible
8000 / 5432 / 6379 non accessibles depuis l'hôte
```

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

## Verdict attendu

Le jalon sera GREEN uniquement après observation de :

```text
DC14_ANSIBLE_PASS: second full site convergence changed=0
DC14_CONTAINER_PASS
DC14_VOLUME_PASS
DC14_CONFIG_PASS
DC14_ARTIFACT_PASS
DC14_DATA_PASS
DC14_FUNCTIONAL_PASS
DC14_STRICT_IDEMPOTENCE_PASS
```

## Prochain jalon après GREEN

```text
DC-15 — Package + SHA-256 + artifact
```
