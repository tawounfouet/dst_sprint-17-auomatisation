# 192 — Terraform Providers Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps

## 1. Définition

Un **provider Terraform** est un plug-in permettant à Terraform d’interagir avec une API externe. Le support DataScientest cite aussi bien des fournisseurs cloud que des services SaaS ou des plateformes d’infrastructure.

Exemples vus dans le cours :

- AWS ;
- Azure ;
- Kubernetes ;
- Helm ;
- Docker ;
- OpenStack ;
- DigitalOcean ;
- OVH ;
- GitLab ;
- MySQL ;
- VMware vSphere ;
- Active Directory.

---

## 2. Rôle du provider

Le provider constitue l’interface entre Terraform et la plateforme cible :

```text
Configuration Terraform
        ↓
Terraform Core
        ↓
Provider
        ↓
API du service cible
        ↓
Ressources réelles
```

Terraform Core interprète la configuration et orchestre les changements ; le provider connaît les types de ressources, leurs attributs et les appels API nécessaires.

---

## 3. Déclaration simple

Exemple AWS :

```hcl
provider "aws" {
  region = "eu-west-3"
}
```

Exemple Kubernetes :

```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
}
```

---

## 4. Providers requis

Le support recommande de déclarer les versions dans `required_providers` plutôt que dans le bloc `provider`.

```hcl
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.9.0"
    }
  }
}
```

Pour AWS :

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

---

## 5. Contraintes de version vues dans le cours

```text
=      version exacte
!=     exclut une version
>      supérieure
>=     supérieure ou égale
<      inférieure
<=     inférieure ou égale
~>     autorise l’évolution compatible du composant de version le plus à droite
```

Exemples :

```hcl
version = "<= 2.9.0"
version = ">= 2.9.0"
version = ">= 1.2.0, < 2.0.0"
version = "~> 2.9.0"
```

---

## 6. Initialisation

```bash
terraform init
```

Cette commande prépare le répertoire de travail et télécharge notamment les providers requis.

Le support montre également :

```bash
terraform init -upgrade
```

pour réinitialiser en permettant la mise à niveau des plugins selon les contraintes déclarées.

---

## 7. Fichier de verrouillage

Après `terraform init`, Terraform crée :

```text
.terraform.lock.hcl
```

Le support recommande de versionner ce fichier afin de conserver les sélections de providers entre les exécutions.

---

## 8. Provider Kubernetes

Le cours utilise Kubernetes après installation d’un cluster k3s :

```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
}
```

Ce provider est ensuite utilisé pour gérer :

- secrets ;
- deployments ;
- services ;
- autres objets Kubernetes.

---

## 9. Provider Helm

Le support utilise également Helm pour déployer des charts sur Kubernetes.

```hcl
provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}
```

Puis :

```hcl
resource "helm_release" "wordpress" {
  name      = "wordpress"
  namespace = "wordpress"
  chart     = "${path.module}/wordpress-chart"
}
```

Dans le cours, la distinction principale est :

```text
Provider Kubernetes → ressources Kubernetes directement
Provider Helm       → packages/charts et releases Helm
```

---

## 10. Provider AWS

Le provider AWS est central dans les chapitres suivants :

```hcl
provider "aws" {
  region = "eu-west-3"
}
```

Il est utilisé pour créer ou lire :

- EC2 ;
- VPC ;
- subnets ;
- security groups ;
- EBS ;
- AMI ;
- RDS dans le projet final ;
- S3 pour le backend distant.

Le support montre des clés AWS directement dans certains exemples pédagogiques. Les livrables du dépôt ne reproduisent pas ces identifiants en clair.

---

## 11. Authentification AWS dans les livrables

Le support présente aussi l’usage de variables d’environnement :

```bash
export AWS_ACCESS_KEY_ID=XXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXX
```

Cette approche est utilisée dans le chapitre Modules pour éviter de coder les accès directement dans les fichiers Terraform.

---

## 12. Provider et portabilité

Le cours décrit Terraform comme **cloud agnostic** : plusieurs providers peuvent être pilotés avec un workflow Terraform commun.

```text
terraform init
terraform plan
terraform apply
terraform destroy
```

La syntaxe des ressources reste cependant spécifique au provider utilisé.

---

## 13. Points clés

- Un provider permet à Terraform de communiquer avec une API.
- `required_providers` déclare la source et les contraintes de version.
- `terraform init` télécharge les providers nécessaires.
- `.terraform.lock.hcl` conserve les sélections de versions.
- AWS, Kubernetes et Helm sont les principaux providers manipulés dans le cours.

---

## Source pédagogique

Support DataScientest : **Terraform — Le langage HCL et providers**, avec les cas pratiques Kubernetes, Helm, AWS et Modules.