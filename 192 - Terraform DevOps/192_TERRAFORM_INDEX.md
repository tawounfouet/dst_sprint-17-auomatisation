# 192 — Terraform DevOps — Index

> Sprint 17 — Automatisation  
> Parcours Data Engineer — DataScientest  
> Bloc : Infrastructure as Code avec Terraform

## 1. Objectif du dossier

Ce dossier regroupe les livrables restructurés du module **Terraform DevOps** du Sprint 17 — Automatisation.

Le parcours pédagogique suit la progression du cours DataScientest :

```text
Infrastructure as Code
        ↓
HCL + Providers + Resources
        ↓
Variables + Outputs + Dépendances
        ↓
User Data + Provisioners + Data Sources
        ↓
State + Backends + Expressions
        ↓
Modules + Réutilisabilité
        ↓
Projet final AWS / WordPress
```

L’objectif global est de savoir **décrire, déployer, faire évoluer et structurer une infrastructure reproductible avec Terraform**.

---

## 2. Parcours principal

| Réf. | Document | Thèmes principaux | Durée indicative |
|---|---|---|---:|
| 192.01 | [Introduction et installation](./192.01_TERRAFORM_INTRODUCTION_ET_INSTALLATION.md) | IaC, idempotence, Terraform Core, providers, installation | 1 h |
| 192.02 | [HCL, Providers et Resources](./192.02_TERRAFORM_HCL_PROVIDERS_ET_RESOURCES.md) | HCL, blocs, providers, versions, CLI, ressources, Kubernetes, Helm, AWS | 1 h |
| 192.03 | [Variables, Outputs et Dépendances](./192.03_TERRAFORM_VARIABLES_OUTPUTS_ET_DEPENDANCES.md) | variables, types, validation, tfvars, outputs, références, depends_on | 1 h 30 |
| 192.04 | [User Data, Provisioners et Data Sources](./192.04_TERRAFORM_USER_DATA_PROVISIONERS_DATA_SOURCES.md) | bootstrap EC2, file(), local-exec, remote-exec, data sources | 1 h |
| 192.05 | [State, Backends et Expressions](./192.05_TERRAFORM_STATE_BACKENDS_EXPRESSIONS.md) | tfstate, backend local/S3, migration, count, index, conditions | 1 h |
| 192.06 | [Modules et architecture modulaire](./192.06_TERRAFORM_MODULES_ET_ARCHITECTURE_MODULAIRE.md) | root/child modules, Registry, networking, EC2, réutilisabilité | 1 h |
| 192.07 | [Conclusion et projet final](./192.07_TERRAFORM_CONCLUSION_ET_PROJET_FINAL.md) | WordPress AWS, EC2, RDS, EBS, modules, validation | 5 h |
|  | **Total** |  | **11 h 30** |

---

## 3. Documents transversaux

### Synthèse

- [192_TERRAFORM_SYNTHESE_COMPLETE.md](./192_TERRAFORM_SYNTHESE_COMPLETE.md) — synthèse consolidée de l’ensemble du module.
- [192_TERRAFORM_ARCHITECTURE_AND_WORKFLOW.md](./192_TERRAFORM_ARCHITECTURE_AND_WORKFLOW.md) — architecture conceptuelle et workflow Terraform de bout en bout.

### Documents à produire ensuite

```text
Reference/
├── 192_TERRAFORM_HCL_REFERENCE.md
├── 192_TERRAFORM_PROVIDERS_REFERENCE.md
├── 192_TERRAFORM_RESOURCES_DATA_SOURCES_REFERENCE.md
├── 192_TERRAFORM_VARIABLES_REFERENCE.md
├── 192_TERRAFORM_OUTPUTS_REFERENCE.md
├── 192_TERRAFORM_DEPENDANCES_REFERENCE.md
├── 192_TERRAFORM_PROVISIONERS_REFERENCE.md
├── 192_TERRAFORM_STATE_BACKENDS_REFERENCE.md
├── 192_TERRAFORM_EXPRESSIONS_COUNT_CONDITIONS_REFERENCE.md
├── 192_TERRAFORM_MODULES_REFERENCE.md
└── 192_TERRAFORM_COMMANDES_REFERENCE.md

Synthese/
├── 192_TERRAFORM_AWS_ARCHITECTURE.md
├── 192_TERRAFORM_KUBERNETES_HELM.md
├── 192_TERRAFORM_STATE_ET_COLLABORATION.md
├── 192_TERRAFORM_MODULES_ET_REUTILISABILITE.md
├── 192_TERRAFORM_BEST_PRACTICES.md
├── 192_TERRAFORM_ANTI_PATTERNS_ET_PIEGES.md
└── 192_TERRAFORM_COMPETENCES_A_RETENIR.md

Revision/
├── 192_TERRAFORM_GLOSSAIRE.md
├── 192_TERRAFORM_CHEATSHEET.md
├── 192_TERRAFORM_MEGA_CHEATSHEET.md
├── 192_TERRAFORM_QCM_COURS_ET_CORRIGE.md
├── 192_TERRAFORM_QCM_FINAL_ET_CORRIGE.md
└── 192_TERRAFORM_EXAMEN_BLANC.md
```

---

## 4. Carte des concepts

```text
Terraform
│
├── Infrastructure as Code
│   ├── reproductibilité
│   ├── versionnement
│   ├── automatisation
│   └── idempotence
│
├── Configuration
│   ├── HCL
│   ├── blocks
│   ├── arguments
│   ├── variables
│   ├── locals
│   └── outputs
│
├── Terraform Core
│   ├── lecture de la configuration
│   ├── graphe de dépendances
│   ├── planification
│   └── orchestration des changements
│
├── Providers
│   ├── AWS
│   ├── Kubernetes
│   ├── Helm
│   └── autres APIs
│
├── Objets Terraform
│   ├── resources
│   └── data sources
│
├── Cycle d’exécution
│   ├── init
│   ├── fmt
│   ├── validate
│   ├── plan
│   ├── apply
│   └── destroy
│
├── State
│   ├── terraform.tfstate
│   ├── backend local
│   └── backend S3
│
├── Expressions
│   ├── count
│   ├── count.index
│   ├── length()
│   └── expressions conditionnelles
│
└── Modules
    ├── root module
    ├── child modules
    ├── inputs
    ├── outputs
    └── Terraform Registry
```

---

## 5. Workflow Terraform minimal

```text
Écrire / modifier *.tf
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
Infrastructure
        ↓
Contrôles / tests
        ↓
terraform destroy
(si environnement éphémère ou exercice)
```

Les cinq commandes centrales à mémoriser sont :

```bash
terraform init
terraform validate
terraform plan
terraform apply
terraform destroy
```

`terraform fmt` complète ce workflow en normalisant la mise en forme du code.

---

## 6. Organisation logique d’un projet Terraform

Une configuration simple peut être organisée ainsi :

```text
terraform-project/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

Une configuration modulaire évolue vers :

```text
terraform-project/
├── main.tf
├── variables.tf
├── outputs.tf
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ec2/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── scripts/
    └── bootstrap.sh
```

Le projet final du cours ajoute notamment des modules dédiés au réseau, au calcul, à la base de données et au stockage.

---

## 7. Mémo : Resource vs Data Source

```text
resource
   ↓
Terraform crée ou gère un objet

ex. aws_instance
```

```text
data
   ↓
Terraform lit une information existante

ex. aws_ami
```

Exemple de référence :

```hcl
ami = data.aws_ami.amazon_linux.id
```

---

## 8. Mémo : Variable vs Local vs Output

| Élément | Rôle |
|---|---|
| `variable` | entrée configurable du module |
| `local` | valeur interne calculée ou mutualisée |
| `output` | valeur exposée par le module ou affichée à l’utilisateur |

Exemple :

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

locals {
  resource_name = "datascientest-${var.environment}"
}

output "instance_ip" {
  value = aws_instance.web.public_ip
}
```

---

## 9. Mémo : State et collaboration

Sans backend explicite :

```text
Terraform
   ↓
terraform.tfstate local
```

Avec backend distant :

```text
Équipe
  ↓
Terraform
  ↓
Backend distant
  ↓
terraform.tfstate partagé
```

Le cours met en pratique un backend **AWS S3** et la migration d’un state local vers ce backend via :

```bash
terraform init -migrate-state
```

---

## 10. Mémo : modules

Un module est un ensemble de fichiers Terraform réunis dans un même répertoire.

```text
Root Module
│
├── module networking
│   ├── VPC
│   ├── subnets
│   ├── NAT Gateway
│   └── security groups
│
└── module ec2
    ├── instance publique
    ├── instance privée
    └── outputs
```

Les modules permettent principalement :

- la réutilisation ;
- la maintenabilité ;
- une meilleure organisation ;
- la cohérence entre environnements ;
- la réduction de la duplication.

---

## 11. Projet final du module

Le projet final demande de construire une architecture AWS permettant d’héberger un site **WordPress**.

Le besoin inclut :

- région AWS Paris `eu-west-3` ;
- instance EC2 `t3.micro` ;
- récupération dynamique de l’AMI ;
- base de données via `aws_db_instance` ;
- déploiement sur deux Availability Zones ;
- disque EBS supplémentaire de 10 Go ;
- accès HTTP sur le port 80 ;
- HTTPS/TLS en bonus ;
- découpage en modules ;
- absence de mots de passe en dur ;
- déploiement répétable et réutilisable ;
- nettoyage des ressources avec Terraform.

Architecture documentaire demandée :

```text
modules/
├── networking/
├── ec2/
├── rds/
└── ebs/
```

---

## 12. Ordre de révision recommandé

### Niveau 1 — Fondamentaux

1. IaC et approche déclarative.
2. HCL.
3. Provider / Resource / Data Source.
4. `init → plan → apply`.

### Niveau 2 — Paramétrage

5. Variables et `.tfvars`.
6. Outputs.
7. Références entre ressources.
8. Dépendances implicites et explicites.

### Niveau 3 — Exploitation

9. `user_data`.
10. Provisioners.
11. State et backends.
12. Expressions `count`, index et conditions.

### Niveau 4 — Architecture

13. Modules.
14. Registry.
15. Architecture AWS modulaire.
16. Projet final.

---

## 13. Compétences cibles

À l’issue du bloc Terraform, l’objectif est d’être capable de :

- décrire une infrastructure en HCL ;
- configurer un provider ;
- créer et relier des ressources ;
- paramétrer une configuration avec des variables ;
- exposer des informations via des outputs ;
- utiliser des data sources ;
- automatiser le bootstrap d’une machine ;
- comprendre et gérer le state ;
- configurer un backend distant ;
- créer plusieurs ressources dynamiquement ;
- modulariser une architecture ;
- construire une infrastructure AWS reproductible.

---

## 14. Sources pédagogiques

Cet index consolide les sept supports Terraform du Sprint 17 DataScientest : introduction, HCL/providers, variables, user data/data sources, Remote State, modules et projet final. Les éléments propres à l’interface pédagogique ainsi que les identifiants d’accès présents dans les supports sources ne sont pas reproduits.