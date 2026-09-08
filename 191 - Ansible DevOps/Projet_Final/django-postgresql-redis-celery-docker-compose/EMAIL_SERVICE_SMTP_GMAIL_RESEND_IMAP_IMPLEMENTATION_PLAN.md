# Plan d'Implémentation — Service Mail Multi-Environnement (SMTP, Gmail, Resend & IMAP)

Ce document décrit le plan d'implémentation rigoureux pour l'intégration du service email sortant et de la relève entrante IMAP dans le projet `django-postgresql-redis-celery-docker-compose`, structuré sous les jalons **DC-22 à DC-26**.

---

## 1. Objectifs & Découpage des Jalons

```text
DC-22  Configuration Django Email Core & Fallback Console
       ├── Création de config/settings/email.py
       ├── Intégration dans base.py, dev.py, stg.py, prod.py
       ├── Fallback automatique sur console.EmailBackend en DEV si SMTP non configuré
       ├── Règle stricte fail-fast en STAGING (Gmail) et PROD (Resend)
       └── Tests unitaires de politique de configuration (test_settings_email_policy.py)

DC-23  Tâches Asynchrones Celery (Envoi Sortant & Relève IMAP)
       ├── Tâche send_email_async avec retry exponentiel (autoretry_for)
       ├── Tâche check_incoming_emails_imap avec extraction des pièces jointes vers S3
       ├── Endpoint DRF POST /api/tasks/send-email/
       ├── Enregistrement de la tâche périodique IMAP dans Celery Beat
       └── Tests unitaires mockés (test_tasks.py, test_api.py)

DC-24  Docker Compose & Fichiers d'Exemple d'Environnement
       ├── Injection des variables SMTP/IMAP dans x-app-environment (compose.yml)
       ├── Mise à jour de django-app/.env.dev.example (fallback console + option SMTP)
       ├── Mise à jour de django-app/.env.stg.example (Gmail SMTP 587 TLS + IMAP 993)
       └── Mise à jour de django-app/.env.prod.example (Resend SMTP 465 SSL)

DC-25  Paramétrage Ansible & Sécurisation Vault
       ├── Variables group_vars/all.yml pour dev, stg, prod
       ├── Modèles de coffre-fort group_vars/vault.example.yml
       ├── Génération étanche de .env.runtime (0600 root:root)
       └── Conformité secret_hygiene.py pour les identifiants email/API

DC-26  Validation Globale, Static Gate CI & Packaging
       ├── Exécution de la suite de tests unitaires Django (> 60 tests au vert)
       ├── Validation du gate statique (static_checks.sh)
       ├── Validation du package ZIP et scan antifuite (package.sh)
       └── Rapport de clôture DC-26 & Walkthrough
```

---

## 2. Détail des Fichiers Impactés et Tâches Techniques

### 2.1. Composant Django (`django-app/`)

#### [NEW] `django-app/config/settings/email.py`
- Implémenter `configure_email_settings(env)`.
- En `APPLICATION_ENV=dev` : si `SMTP_HOST` ou `SMTP_USER` est absent ou vide, basculer sur `django.core.mail.backends.console.EmailBackend`.
- En `APPLICATION_ENV=stg` et `prod` : validation stricte (`ImproperlyConfigured` si `SMTP_HOST`, `SMTP_USER` ou `SMTP_PASSWORD` est manquant).
- Support des commutateurs `SMTP_USE_TLS` (True pour Gmail port 587) et `SMTP_USE_SSL` (True pour Resend port 465).
- Configuration IMAP (`IMAP_HOST`, `IMAP_PORT`, `IMAP_USER`, `IMAP_PASSWORD`, `IMAP_USE_SSL`).

#### [MODIFY] `django-app/config/settings/base.py`
- Importer `configure_email_settings` et appliquer le dictionnaire retourné aux variables globales Django.

#### [NEW] `django-app/tests/test_settings_email_policy.py`
- Tester le fallback automatique console en DEV quand SMTP n'est pas renseigné.
- Tester l'activation de `smtp.EmailBackend` en DEV quand les variables sont fournies.
- Tester le rejet immédiat (`ImproperlyConfigured`) en STAGING / PROD si les identifiants sont manquants.
- Tester la cohérence des ports par défaut (587 avec TLS, 465 avec SSL).

#### [MODIFY] `django-app/tasks_demo/tasks.py`
- Ajouter `send_email_async(subject, message, recipient_list, from_email=None, attachment_storage_paths=None)` :
  - Décorateur `@shared_task(bind=True, autoretry_for=(Exception,), retry_backoff=True, retry_kwargs={"max_retries": 5})`.
  - Prise en compte optionnelle de pièces jointes lues depuis `default_storage` (S3/MinIO).
- Ajouter `check_incoming_emails_imap()` :
  - Connexion IMAP SSL sécurisée.
  - Recherche des messages `UNSEEN`.
  - Décodage RFC2822 du sujet et de l'expéditeur.
  - Sauvegarde automatique des pièces jointes vers `default_storage.save(f"inbox_attachments/{filename}", ...)`.

#### [MODIFY] `django-app/tasks_demo/serializers.py` & `views.py` & `urls.py`
- Ajouter `EmailSubmissionSerializer(serializers.Serializer)` avec champs `to_email`, `subject`, `message`.
- Ajouter la vue `@api_view(["POST"]) submit_email_task` rattachée à `/api/tasks/send-email/`.
- Déclencher l'envoi asynchrone via `send_email_async.delay(...)` et retourner `HTTP 202 Accepted` avec le `task_id`.

#### [MODIFY] `django-app/tasks_demo/tests/test_tasks.py` & `test_api.py`
- Tester la tâche `send_email_async` avec mock de `django.core.mail.send_mail`.
- Tester la tâche `check_incoming_emails_imap` avec mock de `imaplib.IMAP4_SSL`.
- Tester l'endpoint API `/api/tasks/send-email/` (validation payload, rejet champs vides, acceptation 202).

---

### 2.2. Composant Docker & Environnement (`docker/` et `django-app/`)

#### [MODIFY] `docker/compose.yml`
- Ajouter les variables dans le bloc d'ancrage `x-app-environment` :
  - `SMTP_HOST: ${SMTP_HOST:-}`
  - `SMTP_PORT: ${SMTP_PORT:-}`
  - `SMTP_USER: ${SMTP_USER:-}`
  - `SMTP_PASSWORD: ${SMTP_PASSWORD:-}`
  - `SMTP_USE_TLS: ${SMTP_USE_TLS:-}`
  - `SMTP_USE_SSL: ${SMTP_USE_SSL:-}`
  - `DEFAULT_FROM_EMAIL: ${DEFAULT_FROM_EMAIL:-}`
  - `IMAP_HOST: ${IMAP_HOST:-}`
  - `IMAP_PORT: ${IMAP_PORT:-}`
  - `IMAP_USER: ${IMAP_USER:-}`
  - `IMAP_PASSWORD: ${IMAP_PASSWORD:-}`
  - `IMAP_USE_SSL: ${IMAP_USE_SSL:-}`

#### [MODIFY] `django-app/.env.dev.example`
- Fournir la documentation claire du fallback console et les options commentées o2switch.

#### [MODIFY] `django-app/.env.stg.example`
- Configurer les valeurs types pour Gmail (`smtp.gmail.com`, 587, TLS, mot de passe d'application).

#### [MODIFY] `django-app/.env.prod.example`
- Configurer les valeurs types pour Resend (`smtp.resend.com`, 465, SSL, user `resend`, clé API).

---

### 2.3. Composant Ansible (`ansible-project/`)

#### [MODIFY] `ansible-project/inventories/dev/group_vars/all.yml`
- Déclarer les variables par défaut pour l'environnement dev.

#### [MODIFY] `ansible-project/inventories/stg/group_vars/all.yml` & `vault.example.yml`
- Déclarer les variables Gmail dans `compose_stack_runtime_environment` :
  - `SMTP_HOST: smtp.gmail.com`
  - `SMTP_PORT: "587"`
  - `SMTP_USER: "{{ vault_smtp_user }}"`
  - `SMTP_PASSWORD: "{{ vault_smtp_password }}"`
  - `SMTP_USE_TLS: "true"`
  - `SMTP_USE_SSL: "false"`
  - `IMAP_HOST: imap.gmail.com`
  - `IMAP_PORT: "993"`
  - `IMAP_USER: "{{ vault_smtp_user }}"`
  - `IMAP_PASSWORD: "{{ vault_smtp_password }}"`
  - `IMAP_USE_SSL: "true"`

#### [MODIFY] `ansible-project/inventories/prod/group_vars/all.yml` & `vault.example.yml`
- Déclarer les variables Resend dans `compose_stack_runtime_environment` :
  - `SMTP_HOST: smtp.resend.com`
  - `SMTP_PORT: "465"`
  - `SMTP_USER: resend`
  - `SMTP_PASSWORD: "{{ vault_smtp_password }}"`
  - `SMTP_USE_TLS: "false"`
  - `SMTP_USE_SSL: "true"`
  - `DEFAULT_FROM_EMAIL: "{{ vault_default_from_email | default('notifications@example.com') }}"`

#### [MODIFY] `ansible-project/scripts/secret_hygiene.py`
- Vérifier que les filtres de détection n'émettent aucun faux-positif sur les marqueurs `CHANGE_ME_GMAIL_APP_PASSWORD` ou `CHANGE_ME_RESEND_API_KEY`.

---

## 3. Definition of Done (DoD) — Critères d'Acceptation

```text
[x] DC-22 : configure_email_settings active console.EmailBackend en DEV quand SMTP n'est pas configuré
[x] DC-22 : configure_email_settings active smtp.EmailBackend en DEV dès que SMTP_HOST/SMTP_USER sont fournis
[x] DC-22 : STAGING et PROD lèvent ImproperlyConfigured si SMTP_HOST, USER ou PASSWORD manquent
[x] DC-23 : send_email_async envoie un email sans bloquer l'appelant et gère le retry Celery
[x] DC-23 : check_incoming_emails_imap relève les courriels et stocke les pièces jointes sur S3/MinIO
[x] DC-23 : L'endpoint POST /api/tasks/send-email/ valide le payload et renvoie HTTP 202 avec task_id
[x] DC-24 : docker/compose.yml propage les variables SMTP et IMAP
[x] DC-24 : .env.dev.example, .env.stg.example et .env.prod.example documentent fidèlement chaque cible
[x] DC-25 : Les inventaires Ansible intègrent les configurations Gmail (STG) et Resend (PROD) via Vault
[x] DC-26 : Tous les tests unitaires Django sont au vert (67 tests réussis)
[x] DC-26 : Le gate statique static_checks.sh passe avec succès (DC11_STATIC_GATE_PASS)
[x] DC-26 : Le script package.sh génère l'archive validée sans aucune fuite de secret
```

---

## 4. Matrice des Risques & Mesures d'Atténuation

| Risque identifié | Impact | Stratégie d'atténuation |
|---|---|---|
| **Blocage réseau sur le thread Web** | Latence élevée ou timeout Gunicorn lors des envois d'emails. | Envoi délégué strictement à une tâche Celery asynchrone non-bloquante. |
| **Rejet de connexion par Google (Gmail)** | Échec d'authentification SMTP/IMAP en Staging. | Documentation claire et utilisation impérative des Mots de passe d'application Google 16 caractères (2FA). |
| **Ports SMTP sortants bloqués par le pare-feu de l'hôte** | Impossibilité d'émettre des emails vers l'extérieur. | Utilisation du port standard 587 (STARTTLS) pour Gmail et 465 (SSL) pour Resend. |
| **Fuite des identifiants Google ou clés Resend** | Compromission de compte et risque de spam. | Règle zéro secret en clair dans Git, chiffrement obligatoire avec Ansible Vault. |
| **Volumétrie des pièces jointes IMAP** | Saturation de l'espace disque du conteneur. | Streaming direct du contenu des pièces jointes vers le stockage S3/MinIO sans écriture locale. |
