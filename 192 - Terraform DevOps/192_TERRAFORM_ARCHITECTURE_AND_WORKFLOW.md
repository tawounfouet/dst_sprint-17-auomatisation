# 192 — Terraform DevOps — Architecture & Workflow

> Sprint 17 — Automatisation  
> Vue d’architecture consolidée du module Terraform

## 1. Objectif

Ce document synthétise le fonctionnement de Terraform sous l’angle **architecture + workflow**.

Il répond à quatre questions :

1. Quels sont les composants qui interviennent lorsqu’on exécute Terraform ?
2. Comment Terraform transforme-t-il du HCL en changements d’infrastructure ?
3. Quel rôle joue le state dans ce processus ?
4. Comment structurer une architecture Terraform modulaire et collaborative ?

---

## 2. Architecture conceptuelle de Terraform

Le cours présente Terraform comme l’intermédiaire entre une configuration déclarative et les APIs des plateformes cibles.

```text
┌──────────────────────────────┐
│          Utilisateur         │
└──────────────┬───────────────┘
               │
               │ écrit
               ▼
┌──────────────────────────────┐
│     Configuration *.tf       │
│            HCL               │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│       Terraform Core         │
│                              │
│ - parse la configuration     │
│ - construit les dépendances  │
│ - lit le state               │
│ - calcule le plan            │
│ - orchestre les changements  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│          Provider            │
│ AWS / Kubernetes / Helm ...  │
└──────────────┬───────────────┘
               │
               │ appels API
               ▼
┌──────────────────────────────┐
│ Infrastructure / plateforme  │
│ EC2 / VPC / EBS / RDS / K8s │
└──────────────────────────────┘
```

Terraform Core ne crée pas directement une instance EC2 ou un Deployment Kubernetes. Il s’appuie sur le **provider** adapté, qui connaît l’API et le modèle de ressources du système cible.

---

## 3. Les quatre plans de l’architecture Terraform

Une manière utile de comprendre Terraform est de distinguer quatre plans.

```text
1. Configuration
2. Orchestration
3. État
4. Infrastructure distante
```

### 3.1 Plan de configuration

Contient notamment :

- `resource` ;
- `data` ;
- `variable` ;
- `locals` ;
- `output` ;
- `module` ;
- `provider` ;
- `terraform`.

Exemple :

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
}
```

### 3.2 Plan d’orchestration

Terraform Core :

```text
Configuration
     ↓
Dépendances
     ↓
État courant
     ↓
Plan
     ↓
Exécution
```

### 3.3 Plan d’état

Le state conserve la correspondance entre les objets déclarés et les objets distants.

```text
aws_instance.web
        ↕
terraform.tfstate
        ↕
EC2 i-xxxxxxxx
```

### 3.4 Plan d’infrastructure

Il s’agit des ressources réellement existantes :

- machines ;
- réseaux ;
- volumes ;
- bases de données ;
- workloads Kubernetes ;
- releases Helm ;
- etc.

---

## 4. Workflow de bout en bout

Le workflow principal du cours est :

```text
Écriture HCL
    ↓
terraform fmt
    ↓
terraform init
    ↓
terraform validate
    ↓
terraform plan
    ↓
Revue du plan
    ↓
terraform apply
    ↓
Contrôle de l’infrastructure
    ↓
Évolution de la configuration
    ↓
Nouveau plan / apply
```

Pour un environnement d’exercice ou éphémère :

```text
terraform destroy
```

---

## 5. Étape 1 — Écriture de la configuration

Une configuration simple peut être découpée ainsi :

```text
project/
├── provider.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

Terraform traite les fichiers `.tf` d’un même répertoire comme une configuration de module unique.

### Responsabilités typiques

```text
provider.tf
    → providers / versions / backend

main.tf
    → resources / data sources / modules

variables.tf
    → inputs

terraform.tfvars
    → valeurs des inputs

outputs.tf
    → sorties
```

---

## 6. Étape 2 — Initialisation

Commande :

```bash
terraform init
```

`init` prépare le répertoire pour l’exécution.

Le processus comprend notamment :

```text
terraform init
     │
     ├── initialisation du backend
     │
     ├── résolution des providers
     │
     ├── téléchargement des plugins
     │
     ├── résolution des modules
     │
     └── création/mise à jour du lock file
```

Le cours montre notamment la génération de :

```text
.terraform.lock.hcl
```

---

## 7. Étape 3 — Formatage et validation

### Formatage

```bash
terraform fmt
```

Objectif : homogénéiser le style HCL.

### Validation

```bash
terraform validate
```

Objectif : vérifier que la configuration Terraform est cohérente sur le plan syntaxique et structurel.

Pipeline :

```text
HCL brut
  ↓
fmt
  ↓
HCL formaté
  ↓
validate
  ↓
Configuration valide
```

---

## 8. Étape 4 — Planification

Commande :

```bash
terraform plan
```

Le plan représente la différence entre :

```text
État souhaité
      ↕
État connu / infrastructure
```

Terraform affiche des actions telles que :

```text
+ create
~ update
- destroy
```

Exemple :

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

Le plan est donc une étape de **prévisualisation** avant modification de l’infrastructure.

---

## 9. Étape 5 — Application

Commande :

```bash
terraform apply
```

Architecture :

```text
Plan
 ↓
Terraform Core
 ↓
Provider
 ↓
API distante
 ↓
Création / modification / suppression
 ↓
Mise à jour du state
```

Dans les exercices, la validation interactive est parfois désactivée avec :

```bash
terraform apply -auto-approve
```

---

## 10. Le graphe de dépendances

Terraform déduit les relations entre ressources depuis les références.

Exemple :

```hcl
resource "aws_volume_attachment" "data" {
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}
```

Le graphe devient :

```text
aws_ebs_volume.data ──────┐
                          ├──> aws_volume_attachment.data
aws_instance.web ─────────┘
```

Ainsi, Terraform peut déterminer un ordre d’exécution cohérent.

### Dépendance explicite

```hcl
depends_on = [aws_security_group.web]
```

Le cours recommande de l’utiliser lorsque la dépendance ne peut pas être exprimée naturellement par une référence.

---

## 11. Resource, Data Source et Provider

Ces trois objets ne jouent pas le même rôle.

```text
Provider
   ↓
connexion à l’API
```

```text
Resource
   ↓
création / gestion
```

```text
Data Source
   ↓
lecture / découverte
```

Exemple AWS :

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
}
```

Workflow :

```text
AWS API
  ↓
data.aws_ami
  ↓
AMI ID
  ↓
aws_instance.web
```

---

## 12. Paramétrage de l’architecture

Les variables séparent la logique de l’infrastructure de ses valeurs d’environnement.

```text
variables.tf
     ↓
var.*
     ↓
Resources / Modules
```

Exemple :

```hcl
variable "environment" {
  type    = string
  default = "dev"
}
```

Les valeurs peuvent provenir :

```text
default
terraform.tfvars
*.auto.tfvars
-var
-var-file
TF_VAR_*
```

Cela permet de faire varier les environnements sans recopier toute l’architecture.

---

## 13. Outputs et interfaces

Un output expose un attribut utile :

```hcl
output "public_ip" {
  value = aws_instance.web.public_ip
}
```

Dans un module, les outputs jouent le rôle d’interface vers le module appelant.

```text
module networking
   ↓ output vpc_id
root module
   ↓ input
module ec2
```

C’est une notion centrale dans l’architecture modulaire.

---

## 14. Bootstrap d’une instance avec `user_data`

Le cours utilise `user_data` afin d’exécuter un script lors du lancement d’EC2.

```hcl
resource "aws_instance" "web" {
  user_data = file("install_apache.sh")
}
```

Architecture :

```text
Terraform
   ↓
Create EC2
   ↓
AWS transmet user_data
   ↓
Boot de l’instance
   ↓
Script shell
   ↓
Installation / configuration initiale
```

Cette étape ajoute une première couche de configuration système au provisioning de l’infrastructure.

---

## 15. Provisioners dans le workflow

Le cours introduit trois provisioners :

```text
local-exec
remote-exec
file
```

### `local-exec`

```text
Terraform host
   ↓
commande locale
```

### `file`

```text
machine Terraform
   ↓ copie
machine distante
```

### `remote-exec`

```text
Terraform
   ↓ SSH / WinRM
machine distante
   ↓
commandes
```

Le provisioner s’intègre au cycle d’une ressource et peut également être déclenché lors de la destruction avec :

```hcl
when = destroy
```

---

## 16. State : architecture de correspondance

Terraform doit savoir quelles ressources distantes correspondent aux ressources déclarées.

```text
HCL
 |
 | aws_instance.web
 |
 ▼
State
 |
 | id = i-xxxxxxxx
 |
 ▼
AWS
```

Le state est donc indispensable pour :

- suivre les ressources ;
- lire des attributs ;
- comparer l’existant à la configuration ;
- générer les plans suivants.

---

## 17. Backend local

Architecture par défaut :

```text
Laptop / serveur Terraform
│
├── *.tf
└── terraform.tfstate
```

Cette approche est adaptée au travail individuel ou aux exercices simples.

---

## 18. Backend distant

Le cours migre le state vers AWS S3.

```text
Développeur A ─┐
               │
Développeur B ─┼──> Terraform ───> Backend S3
               │                     │
CI/CD ─────────┘                     └── terraform.tfstate
```

Configuration conceptuelle :

```hcl
terraform {
  backend "s3" {
    bucket = "example-terraform-state"
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
```

Migration :

```bash
terraform init -migrate-state
```

L’architecture du state devient indépendante de la machine locale qui exécute Terraform.

---

## 19. Collections et `count`

Avec :

```hcl
count = 3
```

une ressource logique devient plusieurs instances de ressource.

Avant :

```text
aws_instance.web
```

Après :

```text
aws_instance.web[0]
aws_instance.web[1]
aws_instance.web[2]
```

### Impact architectural

Toute ressource dépendante doit gérer cette cardinalité.

```text
EC2[0] ─── EBS[0]
EC2[1] ─── EBS[1]
EC2[2] ─── EBS[2]
```

Le cours utilise :

```hcl
count.index
```

et :

```hcl
length(...)
```

pour aligner les collections.

---

## 20. Conditions

Terraform combine `count` et une expression ternaire :

```hcl
count = var.environment == "dev" ? 1 : 3
```

Architecture logique :

```text
                environment
                    │
          ┌─────────┴──────────┐
          │                    │
        dev                  autre
          │                    │
     count = 1             count = 3
```

Cela rend l’infrastructure adaptable aux environnements.

---

## 21. Architecture Kubernetes utilisée dans le cours

Terraform est également utilisé contre l’API Kubernetes.

```text
Terraform
   ↓
Provider Kubernetes
   ↓
~/.kube/config
   ↓
Kubernetes API Server
   ↓
┌─────────────────────┐
│ Secret              │
│ Deployment MySQL    │
│ Service MySQL       │
│ Deployment WordPress│
│ Service WordPress   │
└─────────────────────┘
```

La validation se fait ensuite avec :

```bash
kubectl get all
```

---

## 22. Architecture Helm utilisée dans le cours

Le provider Helm ajoute une couche de packaging applicatif.

```text
Terraform
   ↓
Provider Helm
   ↓
Helm Chart
   ↓
Kubernetes
```

Cas du cours :

```text
helm_release.mysql
        ↓
helm_release.wordpress
```

La seconde release utilise une dépendance explicite vers MySQL.

---

## 23. Architecture modulaire Terraform

Lorsque la configuration devient importante, le cours la découpe en modules.

```text
Root Module
│
├── module networking
│   ├── VPC
│   ├── Availability Zones
│   ├── private subnets
│   ├── public subnets
│   ├── NAT Gateway
│   └── Security Groups
│
└── module ec2
    ├── EC2 publique
    ├── EC2 privée
    ├── AMI Data Source
    ├── user_data
    └── outputs
```

### Interfaces

```text
Root
  │
  ├── namespace ──────────────> networking
  │                               │
  │                         vpc / sg outputs
  │                               │
  └───────────────────────────────┴──> ec2
```

Les modules communiquent donc par **variables d’entrée** et **outputs**.

---

## 24. Module local vs Registry

### Module local

```hcl
module "ec2" {
  source = "./modules/ec2"
}
```

### Registry

Le cours consomme le module VPC :

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
}
```

Architecture :

```text
Root Module
   ↓
Module networking local
   ↓
Module VPC Registry
   ↓
AWS Provider
```

Cela montre qu’un module peut lui-même composer d’autres modules.

---

## 25. Architecture cible du projet final

Le projet final demande une architecture WordPress AWS structurée en modules.

```text
                           Internet
                              │
                              ▼
                     ┌────────────────┐
                     │ Security Group │
                     │ HTTP : 80      │
                     │ HTTPS : bonus  │
                     └───────┬────────┘
                             │
                             ▼
                     ┌────────────────┐
                     │      EC2       │
                     │   WordPress    │
                     │    t3.micro    │
                     └───────┬────────┘
                             │
                  ┌──────────┴──────────┐
                  │                     │
                  ▼                     ▼
            ┌───────────┐        ┌─────────────┐
            │ EBS 10 Go │        │     RDS     │
            │ persistant│        │ db.t3.micro │
            └───────────┘        └──────┬──────┘
                                       │
                              Multi-AZ / 2 AZ
```

Cette architecture doit être construite à partir de modules :

```text
modules/
├── networking/
├── ec2/
├── rds/
└── ebs/
```

---

## 26. Architecture logique du projet final

```text
Root Module
│
├── networking
│   ├── VPC
│   ├── subnets
│   ├── routes
│   └── security groups
│
├── ec2
│   ├── AMI dynamique
│   ├── EC2 t3.micro
│   ├── WordPress bootstrap
│   └── outputs
│
├── ebs
│   ├── volume 10 Go
│   └── attachment EC2
│
└── rds
    ├── aws_db_instance
    ├── DB subnet placement
    └── Multi-AZ
```

Les outputs des modules réseau doivent alimenter les modules qui en dépendent.

---

## 27. Workflow de développement du projet final

```text
1. Définir les variables
        ↓
2. Construire networking
        ↓
3. Exposer IDs réseau en outputs
        ↓
4. Construire EC2
        ↓
5. Ajouter bootstrap WordPress
        ↓
6. Construire EBS
        ↓
7. Construire RDS
        ↓
8. Relier les modules
        ↓
9. terraform fmt
        ↓
10. terraform init
        ↓
11. terraform validate
        ↓
12. terraform plan
        ↓
13. terraform apply
        ↓
14. Tests fonctionnels
        ↓
15. terraform destroy
```

---

## 28. Séparation configuration / secrets

Le cours montre d’abord certaines valeurs directement dans les configurations pédagogiques, puis recommande de ne pas exposer les credentials AWS dans les fichiers.

Architecture cible :

```text
Code Terraform
      │
      ├── aucune access key en dur
      └── aucune secret key en dur

Environnement d’exécution
      │
      ├── AWS_ACCESS_KEY_ID
      └── AWS_SECRET_ACCESS_KEY
```

Même logique pour les données sensibles de l’application : elles doivent être fournies par des mécanismes de variables plutôt que figées dans le code du projet final.

---

## 29. Séparation Infrastructure / Configuration système

Le cours fait apparaître deux responsabilités :

```text
Terraform
    ↓
Provision infrastructure
```

puis :

```text
user_data / provisioner
    ↓
Bootstrap système/application
```

Ce point prépare naturellement la complémentarité avec Ansible dans le Sprint 17 : Terraform provisionne l’infrastructure tandis qu’un outil de configuration peut prendre en charge la configuration logicielle détaillée.

---

## 30. Architecture collaborative cible

À partir des notions du cours :

```text
                  Git Repository
                       │
             configuration Terraform
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   Développeur      Développeur      CI/CD
        │              │              │
        └──────────────┼──────────────┘
                       ▼
                   Terraform
                       │
              ┌────────┴─────────┐
              │                  │
              ▼                  ▼
         Backend S3          Providers
           State                │
                               APIs
                                │
                                ▼
                         Infrastructure
```

Ce modèle rassemble :

- versionnement du code ;
- state partagé ;
- providers ;
- infrastructure distante ;
- exécution reproductible.

---

## 31. Carte mentale du cycle de vie

```text
                    ┌───────────────┐
                    │ Configuration │
                    └───────┬───────┘
                            │
                          init
                            │
                         validate
                            │
                           plan
                            │
                    ┌───────▼───────┐
                    │     Apply     │
                    └───────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
            State        Provider     Infrastructure
              ▲             │             │
              └─────────────┴─────────────┘
                            │
                         évolution
                            │
                            └──> nouveau plan
```

---

## 32. Les relations à mémoriser

### Provider ↔ API

```text
Provider = adaptateur vers la plateforme
```

### Resource ↔ objet géré

```text
Resource = objet que Terraform crée ou pilote
```

### Data Source ↔ objet lu

```text
Data Source = information récupérée sans création
```

### Variable ↔ input

```text
Variable = paramètre entrant
```

### Output ↔ output

```text
Output = valeur exposée
```

### State ↔ mémoire

```text
State = correspondance configuration / infrastructure
```

### Module ↔ abstraction

```text
Module = ensemble réutilisable de configuration
```

---

## 33. Workflow condensé à retenir

```text
                ┌──────────┐
                │   HCL    │
                └────┬─────┘
                     │
                    init
                     │
                 validate
                     │
                    plan
                     │
                   apply
                     │
          ┌──────────┴──────────┐
          │                     │
        State                Provider
          │                     │
          │                    API
          │                     │
          └──────────┬──────────┘
                     ▼
              Infrastructure
```

---

## 34. Résumé architectural

Terraform met en œuvre une boucle de réconciliation déclarative :

```text
Configuration HCL
      +
Terraform State
      +
État lu via les Providers
      ↓
Plan de changements
      ↓
Appels API
      ↓
Infrastructure mise à jour
      ↓
State mis à jour
```

La montée en maturité du cours consiste ensuite à rendre cette boucle :

- paramétrable avec les variables ;
- dynamique avec les data sources ;
- adaptable avec les expressions ;
- collaborative avec le remote state ;
- réutilisable avec les modules ;
- exploitable dans une architecture AWS complète.

---

## 35. Sources pédagogiques

Ce document est dérivé des sept chapitres Terraform du Sprint 17 DataScientest : introduction, HCL/providers/resources, variables/outputs/dépendances, user data/provisioners/data sources, Remote State/expressions, modules et projet final WordPress AWS. Les secrets et identifiants d’accès présents dans les supports sources ne sont pas reproduits.