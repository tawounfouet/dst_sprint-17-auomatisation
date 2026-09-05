# Terraform — Kubernetes & Helm

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Type : Synthèse technique

## 1. Objectif

Ce document synthétise le cas pratique Kubernetes/Helm du cours Terraform DataScientest. Il montre comment Terraform peut piloter un cluster Kubernetes existant à travers deux providers complémentaires :

- `kubernetes` pour gérer directement les ressources Kubernetes ;
- `helm` pour déployer des applications packagées sous forme de charts.

---

## 2. Mise en place du cluster avec k3s

Le support utilise **k3s**, distribution légère de Kubernetes adaptée à un environnement de lab.

Installation :

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
```

Vérification :

```bash
kubectl version
```

Le lab utilise une installation mono-nœud regroupant les composants du cluster.

La configuration Kubernetes est ensuite exportée pour être consommée par Terraform :

```bash
mkdir -p ~/.kube
kubectl config view --raw > ~/.kube/config
```

---

## 3. Provider Kubernetes

Terraform se connecte au cluster grâce au provider `kubernetes` :

```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
}

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.9.0"
    }
  }
}
```

Le rôle du provider est de traduire la configuration Terraform en appels vers l’API Kubernetes.

```text
Terraform Core
      ↓
Provider Kubernetes
      ↓
Kubernetes API Server
      ↓
Cluster
```

---

## 4. Déploiement direct de ressources Kubernetes

Le cours déploie une application WordPress/MySQL directement avec des ressources Terraform.

Les objets manipulés sont notamment :

```text
kubernetes_secret
kubernetes_deployment
kubernetes_service
```

Le lab crée :

- un déploiement WordPress ;
- un déploiement MySQL ;
- les services associés ;
- des secrets pour le mot de passe et l’utilisateur MySQL.

---

## 5. Locals pour les labels

Le support introduit les `locals` afin de centraliser des valeurs répétées.

Exemple :

```hcl
locals {
  wordpress_labels = {
    App  = "datascientest-wordpress"
    Tier = "frontend"
  }
}
```

Ils sont ensuite réutilisés pour les labels et selectors Kubernetes.

```text
locals
  ↓
labels communs
  ↓
deployment / pod template / service selector
```

L’objectif est de limiter les répétitions tout en conservant un code lisible.

---

## 6. Déploiement WordPress

Le déploiement WordPress est représenté par une ressource `kubernetes_deployment`.

Extrait simplifié :

```hcl
resource "kubernetes_deployment" "wordpress" {
  metadata {
    name   = "datascientest-wordpress"
    labels = local.wordpress_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.wordpress_labels
    }

    template {
      metadata {
        labels = local.wordpress_labels
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:4.8-apache"
        }
      }
    }
  }
}
```

---

## 7. Services Kubernetes

WordPress est exposé via un service `NodePort` :

```hcl
resource "kubernetes_service" "wordpress" {
  metadata {
    name = "wordpress-service"
  }

  spec {
    selector = local.wordpress_labels

    port {
      port        = 80
      target_port = 80
      node_port   = 32000
    }

    type = "NodePort"
  }
}
```

Le lab utilise ainsi :

```text
Client
  ↓
NodePort 32000
  ↓
Service WordPress
  ↓
Pod WordPress
```

MySQL est également exposé via un service, destiné à être consommé par WordPress.

---

## 8. Secrets Kubernetes

Le cours introduit `kubernetes_secret` pour fournir certaines valeurs au déploiement MySQL et WordPress.

Le support précise que le codage en dur des mots de passe est utilisé uniquement pour simplifier l’exercice et n’est pas recommandé en production.

Exemple de référence depuis un conteneur :

```hcl
env {
  name = "WORDPRESS_DB_PASSWORD"

  value_from {
    secret_key_ref {
      name = "mysql-password"
      key  = "password"
    }
  }
}
```

---

## 9. Workflow Terraform sur Kubernetes

Le cycle utilisé dans le lab est :

```bash
terraform init
terraform plan
terraform apply -auto-approve
kubectl get all
terraform destroy -auto-approve
```

Cela illustre bien la séparation entre :

- Terraform, qui gère le cycle de vie déclaré ;
- `kubectl`, utilisé pour inspecter les ressources du cluster.

---

## 10. Pourquoi Helm ?

Le deuxième cas pratique déploie la même application avec Helm.

Helm est présenté comme un gestionnaire de packages pour Kubernetes. Une application est distribuée sous forme de **chart**, contenant :

```text
Chart.yaml
values.yaml
templates/
```

Cette approche permet de paramétrer des manifests Kubernetes réutilisables.

---

## 11. Création des charts

Le cours crée deux charts :

```text
mysql-chart
wordpress-chart
```

Commande :

```bash
helm create mysql-chart
helm create wordpress-chart
```

Les fichiers générés sont ensuite simplifiés pour conserver principalement :

- `deployment.yaml` ;
- `service.yaml` ;
- `values.yaml` ;
- les helpers nécessaires.

---

## 12. Paramétrage avec `values.yaml`

Le chart MySQL définit par exemple :

```yaml
replicaCount: 1

image:
  repository: mysql:5.6
  pullPolicy: IfNotPresent

deployment:
  name: mysql-deployment

service:
  name: mysql-service
  type: ClusterIP
  port: 3306
```

WordPress définit notamment :

```yaml
replicaCount: 1

image:
  repository: wordpress:4.8-apache
  pullPolicy: IfNotPresent

service:
  name: wordpress-service
  type: NodePort
  port: 80
  nodePort: 32000
```

---

## 13. Provider Helm

Terraform pilote Helm via le provider `helm`.

Exemple :

```hcl
provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}
```

Puis chaque chart devient une ressource `helm_release`.

```hcl
resource "helm_release" "mysql" {
  name      = "mysql"
  namespace = "wordpress"
  chart     = "${path.module}/mysql-chart"

  values = [
    file("${path.module}/mysql-chart/values.yaml")
  ]

  create_namespace = true
}
```

---

## 14. Dépendance MySQL → WordPress

Le cours impose l’installation de MySQL avant WordPress :

```hcl
resource "helm_release" "wordpress" {
  # ...

  depends_on = [
    helm_release.mysql
  ]
}
```

Le graphe logique devient :

```text
mysql-chart
     ↓
helm_release.mysql
     ↓
wordpress-chart
     ↓
helm_release.wordpress
```

---

## 15. Vérification Helm

Après déploiement :

```bash
helm ls -n wordpress
kubectl get pod -n wordpress
```

Le cours vérifie ainsi :

- les releases Helm ;
- les pods ;
- les services ;
- les deployments ;
- les ReplicaSets.

---

## 16. Kubernetes Provider vs Helm Provider

| Provider | Rôle principal |
|---|---|
| `kubernetes` | Gérer directement les objets Kubernetes |
| `helm` | Gérer des releases Helm et des charts |

Le support résume cette distinction par la différence entre :

```text
Ressources unitaires Kubernetes
            vs
Packages / versions d’applications Helm
```

---

## 17. Deux stratégies vues dans le cours

### Stratégie 1 — Terraform → Kubernetes directement

```text
Terraform
   ↓
kubernetes_deployment
kubernetes_service
kubernetes_secret
   ↓
Kubernetes API
```

### Stratégie 2 — Terraform → Helm → Kubernetes

```text
Terraform
   ↓
helm_release
   ↓
Helm Chart
   ↓
Kubernetes Resources
```

---

## 18. Nettoyage

Le lab supprime d’abord les ressources Terraform :

```bash
terraform destroy -auto-approve
```

Puis le cluster k3s :

```bash
/usr/local/bin/k3s-uninstall.sh
rm -rf ~/.kube/config
```

---

## 19. À retenir

1. Terraform peut piloter Kubernetes via son provider dédié.
2. `~/.kube/config` permet au provider de connaître le cluster cible.
3. Les ressources Kubernetes peuvent être déclarées directement en HCL.
4. Helm permet de packager et paramétrer des applications Kubernetes.
5. Terraform peut gérer les releases Helm avec `helm_release`.
6. `depends_on` peut imposer un ordre lorsque la dépendance n’est pas suffisamment exprimée autrement.
7. `kubectl` et `helm` restent utiles pour vérifier le résultat après `terraform apply`.

---

## Source pédagogique

Synthèse construite à partir du chapitre DataScientest **« Terraform — Le langage HCL et providers »**, notamment les cas pratiques k3s, Kubernetes, WordPress/MySQL et Helm.