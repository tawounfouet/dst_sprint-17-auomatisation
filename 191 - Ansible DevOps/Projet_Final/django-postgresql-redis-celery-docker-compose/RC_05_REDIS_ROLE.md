# RC-05 — Rôle Ansible Redis

## Statut

**IMPLÉMENTÉ ✅ — NON ENCORE QUALIFIÉ RUNTIME DANS `site.yml`**

RC-05 ajoute un rôle Ansible dédié à Redis pour la variante mono-serveur Django/PostgreSQL/Redis/Celery.

## Structure ajoutée

```text
ansible-project/roles/redis/
├── defaults/main.yml
├── tasks/main.yml
├── handlers/main.yml
└── meta/main.yml
```

## Contrat Redis

La configuration cible est :

```text
bind 127.0.0.1
port 6379
protected-mode yes
supervised systemd
requirepass <secret Vault>
```

Redis n'a donc pas vocation à être exposé publiquement dans cette architecture.

## Packages

Le rôle installe :

```text
redis-server
redis-tools
```

`redis-tools` fournit notamment `redis-cli`, utilisé par le contrôle runtime local.

## Secret

Le rôle consomme :

```yaml
redis_password: "{{ vault_redis_password }}"
```

avec les garde-fous suivants :

```text
secret défini
longueur >= 16
valeur différente de CHANGE_ME_REDIS_PASSWORD
```

Les tâches manipulant le secret utilisent `no_log: true`.

## Validation locale prévue par le rôle

Après application des éventuels handlers, le rôle :

1. vérifie que `redis-server` est enabled/started ;
2. attend `127.0.0.1:6379` ;
3. exécute un `redis-cli ... ping` authentifié ;
4. exige exactement `PONG`.

Le secret n'est pas fourni à `redis-cli` comme argument `-a` ; il est injecté via :

```text
REDISCLI_AUTH
```

et l'appel est masqué par `no_log: true`.

## Idempotence visée

Les directives Redis sont gérées avec `ansible.builtin.lineinfile` et un handler de redémarrage. Au deuxième passage sans changement attendu, les lignes doivent rester stables et le handler ne doit pas être déclenché.

La preuve stricte `changed=0` sera obtenue plus tard sur le `site.yml` complet.

## Ce que RC-05 ne prouve pas encore

RC-05 ne prouve pas encore :

- que le rôle est orchestré par `site.yml` ;
- que Redis démarre réellement dans le harness GitHub Actions de cette variante ;
- que `6379` est inaccessible depuis l'extérieur du host ;
- qu'un message Celery transite réellement par Redis `/0` ;
- que le result backend `/1` fonctionne ;
- qu'un worker Celery consomme les tâches ;
- que le second déploiement global reste à `changed=0`.

Ces preuves arriveront avec l'orchestration, la validation runtime et l'E2E.

## Django Celery Beat

`django-celery-beat` n'est pas encore intégré. RC-05 concerne uniquement le broker/result backend Redis. L'ajout d'un scheduler périodique Django persistant sera traité séparément afin de ne pas mélanger le rôle Redis avec le runtime Celery/Beat.

## Critères de sortie RC-05

```text
rôle redis dédié                         ✅
redis-server / redis-tools               ✅
bind localhost-only                      ✅
protected-mode yes                       ✅
requirepass via Vault                    ✅
service systemd                          ✅
handler restart                          ✅
PING authentifié prévu dans le rôle      ✅
no_log sur opérations secrètes           ✅
preuve E2E Redis réelle                  ⏳
preuve changed=0 globale                 ⏳
```

## Prochaine étape

**RC-06 — rôle Ansible Celery Worker** : unité systemd dédiée, `WorkingDirectory`, `EnvironmentFile`, lancement depuis `.venv`, faible concurrence adaptée au labo et contrôle de service.

Après RC-06, l'ajout de `django-celery-beat` pourra être inséré proprement comme jalon dédié avant l'orchestration globale si l'on veut inclure aussi la planification périodique dans la qualification finale.
