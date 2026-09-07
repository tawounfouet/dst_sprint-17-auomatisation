# Politique de rotation des secrets — Docker Compose multi-environnement

## Principe

Les secrets sont **propres à chaque environnement**. On promeut l'image Docker entre STG et PROD, jamais les secrets.

```text
DEV Vault  != STG Vault != PROD Vault
```

Chaque Vault réel doit contenir :

```text
vault_environment
vault_secret_generation
vault_django_secret_key
vault_postgresql_password
vault_redis_password
```

`vault_environment` doit correspondre exactement à l'inventory utilisé et `vault_secret_generation` est incrémenté à chaque campagne de rotation coordonnée.

## Règles générales

1. Générer de nouvelles valeurs indépendantes et suffisamment longues.
2. Ne jamais réutiliser une valeur entre DEV, STG et PROD.
3. Modifier uniquement le Vault chiffré de l'environnement concerné.
4. Incrémenter `vault_secret_generation`.
5. Déployer l'environnement concerné, puis exécuter les validations runtime et le scan anti-fuite.
6. Ne jamais copier un `.env.runtime` d'un environnement vers un autre.
7. Conserver les anciennes valeurs uniquement dans un stockage sécurisé externe si un rollback est requis ; jamais dans Git, un log ou un artifact.

## `vault_django_secret_key`

Une rotation de `SECRET_KEY` peut invalider des sessions/signatures Django. Le projet n'implémente pas encore `SECRET_KEY_FALLBACKS`; la rotation doit donc être traitée comme une opération applicative coordonnée.

Procédure minimale : nouvelle clé dans le Vault → redéploiement web/worker/beat → validation fonctionnelle → suppression de l'ancienne clé du stockage sécurisé de rollback lorsque la fenêtre de retour est fermée.

## `vault_redis_password`

Le mot de passe Redis est utilisé par Redis lui-même, Django, Celery Worker et Celery Beat. La rotation doit donc être coordonnée au niveau de la stack : nouvelle valeur dans le Vault → régénération de `.env.runtime` → recréation des services Redis et clients → PING authentifié + tâches Celery E2E.

Une période de perturbation courte peut exister si les clients et Redis n'utilisent pas simultanément la même génération.

## `vault_postgresql_password`

Point critique : sur l'image PostgreSQL officielle, `POSTGRES_PASSWORD` configure le rôle lors de **l'initialisation du volume**. Changer uniquement la variable d'environnement sur une base déjà initialisée ne change pas automatiquement le mot de passe du rôle PostgreSQL existant.

La rotation réelle doit donc inclure une opération SQL contrôlée de modification du rôle applicatif, puis la mise à jour coordonnée de `DATABASE_URL` et des services consommateurs. Cette opération n'est pas automatisée dans DC-09 et devra disposer d'un runbook dédié avant usage production.

## Rotation d'urgence

En cas de fuite suspectée :

```text
révoquer / remplacer immédiatement la valeur
        ↓
redéployer l'environnement concerné
        ↓
scanner logs + artifacts
        ↓
révoquer les artifacts compromis si nécessaire
        ↓
purger l'historique Git uniquement si un secret a réellement été commité
```

La rotation est obligatoire même si l'historique Git est ensuite nettoyé : un secret exposé doit être considéré comme compromis.

## Accès Docker

Les secrets injectés comme variables d'environnement sont protégés par le fichier `.env.runtime` en `0600`, mais restent visibles à un utilisateur ayant accès root ou au socket/API Docker. L'accès Docker équivaut donc à un accès privilégié aux secrets runtime.

## Ce que DC-09 ne prétend pas encore qualifier

La politique existe et les garde-fous Ansible sont implémentés, mais aucune rotation réelle PostgreSQL/Redis/Django n'est encore exécutée ni qualifiée par CI/E2E.
