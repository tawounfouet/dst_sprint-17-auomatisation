# Plan d'Implémentation — Variabilisation du Nom de l'Application (`APPLICATION_NAME = dst-ansible-django`)

Ce document formalise le plan d'implémentation pour l'introduction et la variabilisation complète du nom global de l'application Django (`APPLICATION_NAME`), sans conservation de code legacy ni de rétrocompatibilité avec l'ancien nom `datascientest-ansible-django`. La nouvelle valeur par défaut canonique est **`dst-ansible-django`**.

---

## 1. Objectifs & Découpage des Tâches

```text
LOT-APP-01 : Configuration Django & Celery Core
             ├── Déclaration de APPLICATION_NAME dans config/settings/base.py
             ├── Dynamisation du nom d'instance Celery dans config/celery.py
             └── Intégration dans les vues de santé / métadonnées health/views.py (/ et /api/info/)

LOT-APP-02 : Réécriture des Tests Unitaires & Politiques Django
             ├── Mise à jour stricte de tests/test_health.py sur "dst-ansible-django"
             ├── Ajout du test de surcharge dynamique de APPLICATION_NAME dans test_health.py
             └── Ajout de APPLICATION_NAME dans tests/test_settings_runtime_policy.py

LOT-APP-03 : Docker Compose & Templates d'Environnement
             ├── Déclaration de APPLICATION_NAME dans x-app-environment (docker/compose.yml)
             ├── Mise à jour de django-app/Dockerfile (ARG, ENV, LABEL OCI)
             └── Mise à jour des modèles .env.dev.example, .env.stg.example, .env.prod.example

LOT-APP-04 : Ansible, Validation & Tests E2E
             ├── Déclaration de application_name: dst-ansible-django dans inventories/{dev,stg,prod}/group_vars/all.yml
             ├── Injection dans compose_stack_runtime_environment (APPLICATION_NAME)
             ├── Mise à jour de l'assertion HTTP dans playbooks/validate.yml
             ├── Adaptation des scripts E2E validate_stg_like_e2e.py et validate_dev_full_e2e.py
             └── Injection de APPLICATION_NAME dans ansible-project/tests/static_checks.sh

LOT-APP-05 : Validation CI & Packaging
             ├── Exécution de la suite de tests unitaires Django (100% au vert)
             ├── Validation du gate statique static_checks.sh
             └── Validation de conformité secret_hygiene.py et package.sh
```

---

## 2. Détail des Fichiers et Spécifications Techniques

### 2.1. Django Core (`django-app/`)

#### [MODIFY] `django-app/config/settings/base.py`
- Ajouter l'extraction de `APPLICATION_NAME` via `environ.Env` :
  ```python
  APPLICATION_NAME = env("APPLICATION_NAME", default="dst-ansible-django").strip()
  APPLICATION_ENV = env("APPLICATION_ENV", default=_settings_environment).strip().lower()
  APPLICATION_VERSION = env("APPLICATION_VERSION", default="0.0.0-dev")
  APPLICATION_COMMIT = env("APPLICATION_COMMIT", default="local")
  ```

#### [MODIFY] `django-app/health/views.py`
- Remplacer les valeurs statiques par `settings.APPLICATION_NAME` :
  ```python
  @require_GET
  def home(request):
      return JsonResponse(
          {
              "application": getattr(settings, "APPLICATION_NAME", "dst-ansible-django"),
              "status": "running",
          }
      )

  @require_GET
  def info(request):
      return JsonResponse(
          {
              "application": getattr(settings, "APPLICATION_NAME", "dst-ansible-django"),
              "environment": getattr(settings, "APPLICATION_ENV", "dev"),
              "version": getattr(settings, "APPLICATION_VERSION", "0.0.0-dev"),
              "commit": getattr(settings, "APPLICATION_COMMIT", "local"),
              "runtime": "gunicorn",
              "database": "postgresql",
              "broker": "redis",
              "async_runtime": "celery",
              "scheduler": "django-celery-beat",
          }
      )
  ```

#### [MODIFY] `django-app/config/celery.py`
- Remplacer l'identifiant statique `datascientest_django` par la variable d'environnement :
  ```python
  app_name = os.environ.get("APPLICATION_NAME", "dst_ansible_django").replace("-", "_")
  app = Celery(app_name)
  ```

#### [MODIFY] `django-app/tests/test_health.py`
- Réécrire les tests pour valider strictement `"dst-ansible-django"` :
  ```python
  def test_home(self):
      response = self.client.get("/")
      self.assertEqual(response.status_code, 200)
      self.assertEqual(response.json()["application"], "dst-ansible-django")

  def test_info(self):
      response = self.client.get("/api/info/")
      self.assertEqual(response.status_code, 200)
      payload = response.json()
      self.assertEqual(payload["application"], "dst-ansible-django")
      self.assertEqual(payload["database"], "postgresql")
      self.assertEqual(payload["broker"], "redis")
      self.assertEqual(payload["async_runtime"], "celery")
      self.assertEqual(payload["scheduler"], "django-celery-beat")

  def test_custom_application_name_override(self):
      with self.settings(APPLICATION_NAME="mon-app-custom"):
          response = self.client.get("/")
          self.assertEqual(response.json()["application"], "mon-app-custom")
          response_info = self.client.get("/api/info/")
          self.assertEqual(response_info.json()["application"], "mon-app-custom")
  ```

#### [MODIFY] `django-app/tests/test_settings_runtime_policy.py`
- Ajouter `APPLICATION_NAME` dans les variables canaris de test de politique.

---

### 2.2. Conteneurs & Environnement (`docker/` & `django-app/`)

#### [MODIFY] `docker/compose.yml`
- Ajouter dans `x-app-environment` :
  ```yaml
  APPLICATION_NAME: ${APPLICATION_NAME:-dst-ansible-django}
  APPLICATION_ENV: ${APPLICATION_ENV:-dev}
  APPLICATION_VERSION: ${APPLICATION_VERSION:-0.0.0-dev}
  APPLICATION_COMMIT: ${APPLICATION_COMMIT:-local}
  ```

#### [MODIFY] `django-app/Dockerfile`
- Déclarer :
  ```dockerfile
  ARG APPLICATION_NAME=dst-ansible-django
  ARG APPLICATION_VERSION=0.0.0-dev
  ARG APPLICATION_COMMIT=local

  ENV APPLICATION_NAME=${APPLICATION_NAME} \
      APPLICATION_VERSION=${APPLICATION_VERSION} \
      APPLICATION_COMMIT=${APPLICATION_COMMIT}

  LABEL org.opencontainers.image.title="${APPLICATION_NAME}" \
  ...
  ```

#### [MODIFY] `.env.dev.example`, `.env.stg.example`, `.env.prod.example`
- Ajouter en tête de chaque fichier :
  ```env
  APPLICATION_NAME=dst-ansible-django
  ```

---

### 2.3. Ansible & E2E (`ansible-project/`)

#### [MODIFY] `ansible-project/inventories/{dev,stg,prod}/group_vars/all.yml`
- Déclarer :
  ```yaml
  application_name: dst-ansible-django
  ```
- Et dans `compose_stack_runtime_environment` :
  ```yaml
  APPLICATION_NAME: "{{ application_name }}"
  APPLICATION_ENV: "{{ deployment_environment }}"
  APPLICATION_VERSION: "{{ application_version }}"
  APPLICATION_COMMIT: "{{ application_commit }}"
  ```

#### [MODIFY] `ansible-project/playbooks/validate.yml`
- Mettre à jour l'assertion `/api/info/` :
  ```yaml
  - validate_http_info.json.application == (application_name | default('dst-ansible-django'))
  ```

#### [MODIFY] `ansible-project/tests/e2e/validate_stg_like_e2e.py` & `validate_dev_full_e2e.py`
- Valider le nom de l'application :
  ```python
  expected_app_name = os.environ.get("APPLICATION_NAME", "dst-ansible-django")
  require(info.get("application") == expected_app_name, f"application identity mismatch: expected {expected_app_name}, got {info.get('application')}")
  ```

#### [MODIFY] `ansible-project/tests/static_checks.sh`
- Dans la fonction `write_compose_env()`, injecter :
  ```bash
  APPLICATION_NAME=dst-ansible-django
  ```

---

## 3. Definition of Done (DoD)

```text
[x] LOT-APP-01 : APPLICATION_NAME déclaré dans base.py avec default="dst-ansible-django"
[x] LOT-APP-01 : Endpoints / et /api/info/ renvoient "dst-ansible-django" au lieu de l'ancien nom
[x] LOT-APP-01 : Instance Celery initialisée dynamiquement avec APPLICATION_NAME assaini
[x] LOT-APP-02 : Tests test_health.py réécrits sur "dst-ansible-django" avec test de surcharge dynamique
[x] LOT-APP-02 : test_settings_runtime_policy.py intègre APPLICATION_NAME
[x] LOT-APP-03 : docker/compose.yml propage APPLICATION_NAME dans x-app-environment
[x] LOT-APP-03 : Dockerfile et .env.*.example mis à jour avec dst-ansible-django
[x] LOT-APP-04 : Inventaires Ansible (dev, stg, prod) et validate.yml configurés avec application_name
[x] LOT-APP-04 : validate_stg_like_e2e.py et validate_dev_full_e2e.py alignés sur dst-ansible-django
[x] LOT-APP-05 : static_checks.sh passe avec succès (STATIC_GATE_PASS)
[x] LOT-APP-05 : Suite complète de tests Django au vert (100% pass)
[x] LOT-APP-05 : package.sh génère l'archive validée sans fuite
```
