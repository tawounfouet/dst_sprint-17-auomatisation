# DC-09 — Secure Runtime Configuration

## Statut

```text
IMPLEMENTATION                 ✅
VAULT ENVIRONMENT BINDING      ✅ IMPLEMENTED
RUNTIME ENV PERMISSIONS        ✅ IMPLEMENTED
SECRET HYGIENE SCANNER         ✅ IMPLEMENTED
REPO SCAN GREEN                ⏳
LOG SCAN GREEN                 ⏳
ARTIFACT SCAN GREEN            ⏳
RUNTIME QUALIFIED              ⏳
CI GREEN                       ⏳
```

DC-09 durcit le chemin :

```text
Ansible Vault
    ↓
variables dérivées
    ↓
.env.runtime
    ↓
Docker Compose
    ↓
web / worker / beat / db / redis
```

Aucune preuve GREEN n'est revendiquée avant exécution des futurs gates.

## Séparation stricte DEV / STG / PROD

Les trois `vault.example.yml` portent désormais un identifiant explicite :

```text
vault_environment: dev|stg|prod
vault_secret_generation: 1
```

`site.yml` refuse un Vault dont `vault_environment` ne correspond pas à `deployment_environment`. Cela empêche par exemple un déploiement PROD avec un Vault STG même si le fichier a été copié au mauvais endroit.

Les vrais Vaults restent séparés :

```text
inventories/dev/group_vars/vault.yml
inventories/stg/group_vars/vault.yml
inventories/prod/group_vars/vault.yml
```

Ils sont ignorés par Git.

## Qualité des secrets

Le preflight Ansible impose :

```text
DJANGO_SECRET_KEY  >= 50 caractères
POSTGRES_PASSWORD  >= 24 caractères
REDIS_PASSWORD     >= 24 caractères
```

Les trois valeurs doivent être distinctes et ne doivent pas contenir de marqueurs placeholder tels que `CHANGE_ME`, `REPLACE_ME` ou `SET_IN_ENCRYPTED_VAULT`.

Les mêmes contraintes essentielles sont contrôlées une seconde fois dans le rôle `compose_stack` à partir du contrat runtime. Les tâches de contrôle sont `no_log: true`.

## URLs dérivées

Les inventories continuent de construire :

```text
DATABASE_URL
CELERY_BROKER_URL
CELERY_RESULT_BACKEND
```

à partir des secrets Vault en utilisant `urlencode`.

Le rôle vérifie ensuite :

```text
DATABASE_URL          → postgresql://...@db:5432/...
CELERY_BROKER_URL     → redis://...@redis:6379/...
CELERY_RESULT_BACKEND → redis://...@redis:6379/...
SQLite                → interdit dans Compose
```

Cela permet d'accepter des mots de passe contenant des caractères réservés d'URL sans concaténation naïve.

## `.env.runtime`

Le fichier distant canonique est :

```text
/opt/datascientest-compose/docker/.env.runtime
```

Contrat :

```text
owner  root
group  root
mode   0600
backup false
```

Après rendu, `ansible.builtin.stat` vérifie l'existence, le type de fichier, UID/GID root et le mode exact.

Les fichiers runtime historiques suivants sont supprimés sur l'hôte avant rendu :

```text
.env
.env.dev
.env.stg
.env.prod
```

Le but est d'éviter plusieurs copies plaintext concurrentes contenant les mêmes secrets.

## Redaction Ansible

Les opérations susceptibles de matérialiser ou développer des secrets utilisent `no_log: true`, notamment :

```text
validation des secrets
rendu .env.runtime
docker compose config
convergence docker_compose_v2
migrate / collectstatic / PeriodicTask one-shot
ps Compose exécuté avec le runtime env
```

`ansible.cfg` explicite également :

```text
display_args_to_stdout = False
no_target_syslog = True
```

Cela complète `no_log`; cela ne remplace pas `no_log`.

## Détection anti-fuite

Le nouveau scanner :

```text
ansible-project/scripts/secret_hygiene.py
```

possède trois modes :

```text
repo     → fichiers Git suivis dans cette variante
tree     → logs/répertoires/fichiers
archive  → ZIP
```

Il détecte notamment :

```text
vrais vault.yml suivis
.env.runtime suivi/archivé
.vault_pass
clés privées
plusieurs formats de tokens à forte confiance
affectations littérales de secrets dans fichiers de config/logs
valeurs canaris connues via --secret-values-file
```

La valeur détectée n'est jamais imprimée.

## Intégration aux scripts

`preflight.sh` lance le scan `repo` avant les checks Ansible.

`deploy.sh` et `validate_runtime.sh` scannent leurs logs même lorsque le playbook échoue. Un fichier local `SECRET_VALUES_FILE` peut fournir des canaris/secrets éphémères pour une recherche exacte sans passer les valeurs dans la ligne de commande.

`package.sh` exécute :

```text
repo scan
   ↓
création ZIP avec exclusions sensibles
   ↓
archive scan
   ↓
SHA-256 seulement si le scan passe
```

Les exclusions couvrent maintenant les vrais inventories DEV/STG/PROD, Vaults, `.vault_pass`, `.env.runtime`, clés privées et fichiers de valeurs de scan.

## Rotation

La politique détaillée est documentée dans :

```text
SECURITY_SECRET_ROTATION_POLICY.md
```

Les secrets ne sont jamais promus de STG vers PROD ; seule l'image Docker l'est.

Point important : changer `POSTGRES_PASSWORD` dans Compose ne modifie pas automatiquement le mot de passe d'un rôle PostgreSQL déjà initialisé dans un volume persistant. Une vraie rotation PostgreSQL nécessitera une opération SQL coordonnée.

## Limite de sécurité Docker

Le mode `0600` protège `.env.runtime` contre les utilisateurs non privilégiés de l'hôte. Il ne protège pas les secrets contre root ni contre un utilisateur disposant d'un accès au socket/API Docker : ces acteurs peuvent inspecter l'environnement des conteneurs.

L'accès Docker doit donc être traité comme un accès privilégié aux secrets runtime.

## Limites actuelles

DC-09 n'a pas encore exécuté :

```text
secret_hygiene.py repo en CI
déploiement réel avec Vault chiffré
stat 0600 observé sur hôte
scan de vrais logs CI
scan d'un artifact final
rotation réelle de secrets
```

## Prochain jalon

```text
DC-10 — Runtime Hardening
```

Il renforcera le runtime Docker/Compose : permissions/capabilities, read-only lorsque possible, `no-new-privileges`, tmpfs, healthchecks, limites ressources/PIDs, logging Docker, restart/recovery, network isolation et stratégie firewall/DOCKER-USER sans exposer 8000/5432/6379.
