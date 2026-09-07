# RC-07 — Orchestration globale

## Statut

**IMPLÉMENTÉ ✅ — NON ENCORE QUALIFIÉ RUNTIME**

RC-07 raccorde les rôles Redis, Django, Celery Worker et Django Celery Beat au `site.yml` de la variante mono-serveur.

## Ordre d'exécution

Le playbook principal suit maintenant l'ordre :

```text
common
  ↓
postgresql
  ↓
redis
  ↓
django_app
  ↓
celery
  ↓
celery_beat
  ↓
nginx
```

Cet ordre garantit que :

- PostgreSQL est prêt avant les migrations Django et les tâches DB ;
- Redis est prêt avant Django/Celery ;
- le code Django, le `.venv` et l'EnvironmentFile sont prêts avant le worker ;
- les migrations `django-celery-beat` sont appliquées avant le démarrage de Beat ;
- le frontal Nginx est configuré après les runtimes applicatifs.

## Contrat mono-host

Le `site.yml` valide désormais explicitement que :

```text
app      = 1 host
database = 1 host
app[0]   = database[0]
```

L'inventaire d'exemple devient :

```yaml
all:
  children:
    app:
      hosts:
        server1:
    database:
      hosts:
        server1:
```

La variante n'utilise donc plus l'inventaire d'exemple `app1` + `db1` comme topologie canonique.

## Overrides réseau mono-host

`inventories/prod/group_vars/all.yml` fixe désormais :

```text
postgresql_host              = 127.0.0.1
postgresql_listen_addresses  = 127.0.0.1
postgresql_app_cidr          = 127.0.0.1/32
redis_host                   = 127.0.0.1
redis_bind_address           = 127.0.0.1
django_gunicorn_bind         = 127.0.0.1:8000
```

Le contrat reste donc :

```text
Nginx       → :80
Gunicorn    → 127.0.0.1:8000
PostgreSQL  → 127.0.0.1:5432
Redis       → 127.0.0.1:6379
```

## Secrets

Le `site.yml` valide maintenant les trois secrets runtime :

```text
vault_postgresql_password
vault_django_secret_key
vault_redis_password
```

Les assertions sont `no_log: true` et refusent les placeholders `CHANGE_ME_*`.

## Inventaire prod

Un nouvel exemple est ajouté :

```text
inventories/prod/host_vars/server1.example.yml
```

Le fichier runtime réel correspondant :

```text
inventories/prod/host_vars/server1.yml
```

est ajouté aux exclusions `.gitignore`.

Les anciens exemples `app1.example.yml` et `db1.example.yml` restent temporairement présents pour ne pas casser les contrôles statiques hérités ; leur nettoyage sera traité avec RC-09 lorsque le static gate sera adapté à la nouvelle topologie.

## Ce que RC-07 ne prouve pas

Cette étape ne constitue pas encore une preuve que :

- les sept rôles s'exécutent sans erreur sur Ubuntu 24.04 ;
- Redis répond réellement à `PING` dans le harness final ;
- Celery Worker est actif ;
- Celery Beat est actif ;
- `add(21,21)` traverse réellement Redis et le worker ;
- `periodic_heartbeat` est réellement planifié puis consommé ;
- les ports 8000/5432/6379 sont invisibles depuis l'extérieur du host ;
- le deuxième `site.yml` produit `changed=0`.

Ces preuves appartiennent aux jalons RC-08 à RC-11.

## Critères de sortie RC-07

```text
site.yml orchestre common                         ✅
site.yml orchestre postgresql                     ✅
site.yml orchestre redis                          ✅
site.yml orchestre django_app                     ✅
site.yml orchestre celery                         ✅
site.yml orchestre celery_beat                    ✅
site.yml orchestre nginx                          ✅
ordre des dépendances cohérent                    ✅
contrat mono-host explicite                       ✅
PostgreSQL localhost-only configuré               ✅
Redis localhost-only configuré                    ✅
server1 inventory example                         ✅
server1 runtime host_vars ignoré par Git          ✅
qualification runtime globale                     ⏳
```

## Prochaine étape

**RC-08 — Runtime validation** : étendre `playbooks/validate.yml` pour vérifier PostgreSQL, Redis, Gunicorn, Celery Worker, Celery Beat, Nginx, les endpoints HTTP et préparer les preuves fonctionnelles du round-trip asynchrone.
