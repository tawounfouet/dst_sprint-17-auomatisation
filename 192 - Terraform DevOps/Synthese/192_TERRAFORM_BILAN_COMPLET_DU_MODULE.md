# 192 — Terraform DevOps — Bilan complet du module

> Sprint 17 — Automatisation  
> Formation : Data Engineer — DataScientest  
> Bloc : Terraform DevOps  
> Durée pédagogique : environ 11 h 30  
> Périmètre : cours 192.01 à 192.07, synthèses, références, projet final AWS, déclinaison Azure et qualification CI

---

## 1. Objectif de ce bilan

Ce document synthétise l’ensemble de ce qui a été étudié, restructuré, documenté et mis en pratique autour de **Terraform** dans le cadre du Sprint 17 — Automatisation.

Le travail réalisé ne s’est pas limité à relire le cours. Il a suivi plusieurs niveaux :

```text
Cours DataScientest
        ↓
Nettoyage et restructuration
        ↓
Documentation de référence
        ↓
Synthèses transversales
        ↓
Projet final AWS réellement implémenté
        ↓
Validation CI
        ↓
Préparation à une qualification AWS réelle
        ↓
Transposition multi-cloud vers Microsoft Azure
```

Le résultat est donc à la fois un **bilan pédagogique**, un **bilan technique** et un **bilan pratique**.

---

# 2. Vue d’ensemble du parcours Terraform

Le module Terraform a été organisé autour des sept chapitres suivants :

| Réf. | Chapitre | Idée principale |
|---|---|---|
| 192.01 | Introduction et installation | Infrastructure as Code, Terraform Core, providers, installation |
| 192.02 | HCL, providers et resources | langage HCL, providers, ressources, CLI, premiers déploiements |
| 192.03 | Variables, outputs et dépendances | paramétrage, réutilisabilité, validation, outputs, graphe de dépendances |
| 192.04 | User Data, provisioners et data sources | bootstrap, exécution complémentaire, lecture dynamique d’informations |
| 192.05 | State, backends et expressions | état Terraform, remote state, `count`, expressions conditionnelles |
| 192.06 | Modules et architecture modulaire | root module, child modules, interfaces, réutilisation |
| 192.07 | Conclusion et projet final | déploiement WordPress complet sur AWS avec Terraform |

La progression générale du cours peut être représentée ainsi :

```text
Infrastructure as Code
        ↓
HCL
        ↓
Providers
        ↓
Resources
        ↓
Variables / Outputs / Dépendances
        ↓
Data Sources / User Data / Provisioners
        ↓
State / Remote State
        ↓
Expressions
        ↓
Modules
        ↓
Architecture cloud complète
```

Le fil conducteur a toujours été le même : **passer d’une infrastructure codée en dur et manuelle à une infrastructure déclarative, dynamique, versionnée, reproductible et modulaire**.

---

# 3. Infrastructure as Code — le socle conceptuel

## 3.1 Principe

L’Infrastructure as Code consiste à décrire l’infrastructure sous forme de fichiers de configuration versionnables plutôt qu’à la construire uniquement à la main depuis une console graphique.

```text
Approche manuelle
Console → clics → infrastructure

Approche IaC
Code → Terraform → API provider → infrastructure
```

Terraform décrit l’**état cible** de l’infrastructure. Il compare ensuite cet état à ce qu’il connaît déjà et calcule les changements à réaliser.

## 3.2 Pourquoi l’IaC est importante

Les principaux bénéfices étudiés sont :

- reproductibilité ;
- rapidité de création des environnements ;
- standardisation ;
- réduction des erreurs manuelles ;
- versionnement Git ;
- traçabilité ;
- automatisation ;
- collaboration ;
- possibilité de recréer ou détruire proprement une infrastructure.

## 3.3 Idempotence

La logique recherchée est :

```text
État désiré
    ↓
Terraform compare
    ↓
Détecte le delta
    ↓
Applique uniquement les changements nécessaires
```

Cette notion explique pourquoi Terraform n’est pas simplement un script de création de ressources.

---

# 4. Architecture interne de Terraform

Nous avons distingué deux briques essentielles.

## 4.1 Terraform Core

Terraform Core :

- lit les fichiers `.tf` ;
- interprète HCL ;
- construit le graphe des dépendances ;
- lit le state ;
- calcule le plan ;
- orchestre les actions ;
- appelle les providers.

## 4.2 Providers

Les providers sont les plugins qui permettent à Terraform de communiquer avec les API externes.

Exemples étudiés ou utilisés :

```text
AWS
Azure
Kubernetes
Helm
GCP
Docker
GitLab
DigitalOcean
OpenStack
OVH
```

Architecture simplifiée :

```text
Utilisateur
    ↓
Configuration HCL
    ↓
Terraform Core
    ↓
Provider
    ↓
API cloud / plateforme
    ↓
Infrastructure
```

Le provider constitue donc le pont entre la configuration Terraform et la plateforme cible.

---

# 5. HCL — HashiCorp Configuration Language

HCL est le langage principal utilisé pour écrire les configurations Terraform.

Nous avons étudié :

- les blocs ;
- les arguments ;
- les expressions ;
- les références ;
- les interpolations ;
- les commentaires ;
- les types ;
- les contraintes de version.

Exemple :

```hcl
resource "aws_instance" "web" {
  ami           = var.image_id
  instance_type = var.instance_type
}
```

Une ressource est ensuite référencée avec une adresse telle que :

```hcl
aws_instance.web.id
```

La maîtrise des références est importante car elles permettent à Terraform de construire automatiquement les dépendances entre ressources.

---

# 6. Providers et gestion des versions

Une bonne configuration Terraform déclare ses providers et leurs contraintes de version.

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

Nous avons vu plusieurs formes de contraintes :

```text
= 2.9.0
>= 2.9.0
<= 2.9.0
>= 1.2.0, < 2.0.0
~> 2.9.0
```

Le fichier :

```text
.terraform.lock.hcl
```

permet ensuite de figer les versions réellement résolues des providers et améliore la reproductibilité des déploiements.

---

# 7. Workflow Terraform

Le workflow fondamental étudié est :

```text
Écriture du code
      ↓
terraform fmt
      ↓
terraform init
      ↓
terraform validate
      ↓
terraform plan
      ↓
terraform apply
      ↓
Tests
      ↓
terraform destroy
```

## Commandes clés

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
terraform output
terraform destroy
```

Nous avons également utilisé :

```bash
terraform init -backend=false
terraform init -migrate-state
terraform plan -out=tfplan
terraform apply tfplan
terraform show
terraform output -json
```

Le point essentiel est que **`plan` permet d’observer les changements avant de les exécuter**, alors que `apply` modifie réellement l’infrastructure.

---

# 8. Resources et Data Sources

## 8.1 Resources

Une resource représente un objet que Terraform crée ou gère.

Exemples AWS manipulés :

```text
aws_instance
aws_vpc
aws_subnet
aws_security_group
aws_ebs_volume
aws_db_instance
```

Exemples Azure utilisés ensuite :

```text
azurerm_resource_group
azurerm_virtual_network
azurerm_subnet
azurerm_linux_virtual_machine
azurerm_mysql_flexible_server
azurerm_managed_disk
azurerm_key_vault
```

## 8.2 Data Sources

Une data source permet de lire une information existante sans la créer.

Exemple AWS :

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
}
```

Puis :

```hcl
ami = data.aws_ami.ubuntu.id
```

La distinction fondamentale est :

```text
resource = créer / gérer

data source = rechercher / lire
```

Cela a permis de supprimer plusieurs valeurs codées en dur, notamment les AMI AWS.

---

# 9. Variables d’entrée

Les variables transforment une configuration figée en configuration paramétrable.

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
```

Nous avons étudié les propriétés :

```text
type
default
description
validation
sensitive
nullable
```

## 9.1 Sources possibles d’une variable

```text
valeur par défaut
-var
-var-file
terraform.tfvars
*.auto.tfvars
TF_VAR_*
```

Exemple :

```bash
export TF_VAR_instance_type=t3.micro
```

## 9.2 Variables sensibles

```hcl
variable "password" {
  type      = string
  sensitive = true
}
```

Nous avons retenu une nuance importante : **`sensitive = true` masque principalement l’affichage mais ne signifie pas que la valeur disparaît du state**.

---

# 10. Locals

Les locals permettent de calculer ou centraliser des valeurs internes au module.

```hcl
locals {
  environment   = "prod"
  project       = "wordpress"
  resource_name = "${local.project}-${local.environment}"
}
```

Ils sont utiles notamment pour :

- conventions de nommage ;
- tags communs ;
- expressions intermédiaires ;
- réduction de duplication.

Dans nos projets finaux AWS et Azure, ils servent notamment à construire les tags communs.

---

# 11. Outputs

Les outputs exposent les informations importantes produites par Terraform.

```hcl
output "wordpress_url" {
  value = "http://${module.ec2.public_dns}"
}
```

Ils sont utilisés pour :

- afficher une IP ;
- afficher un DNS ;
- récupérer un endpoint ;
- exposer une valeur d’un module enfant ;
- connecter plusieurs modules entre eux.

Les outputs sont donc aussi l’**interface de sortie d’un module**.

---

# 12. Dépendances et graphe Terraform

Terraform déduit les dépendances à partir des références.

Exemple :

```hcl
volume_id   = aws_ebs_volume.data.id
instance_id = aws_instance.web.id
```

Terraform comprend alors que le volume et l’instance doivent exister avant l’attachement.

Quand une relation logique ne peut pas être déduite automatiquement, il est possible d’utiliser :

```hcl
depends_on = [resource.example]
```

Nous avons retenu que `depends_on` doit rester un mécanisme explicite utilisé seulement lorsque les références naturelles ne suffisent pas.

---

# 13. User Data et bootstrap

`user_data` permet de transmettre un script à une machine virtuelle au démarrage.

Exemple conceptuel :

```hcl
user_data = file("install_wordpress.sh")
```

Dans notre projet AWS, nous avons utilisé un template :

```hcl
user_data = templatefile("${path.module}/user_data.sh.tftpl", {...})
```

Dans Azure, le principe équivalent est transmis via :

```hcl
custom_data = base64encode(templatefile(...))
```

Le bootstrap a été utilisé pour :

- installer Apache ;
- installer PHP ;
- télécharger WordPress ;
- configurer `wp-config.php` ;
- récupérer le secret de base de données ;
- monter le disque supplémentaire ;
- activer éventuellement HTTPS.

---

# 14. Provisioners

Le cours a présenté :

```text
local-exec
remote-exec
file
```

Ils permettent d’exécuter des actions complémentaires au cycle de vie Terraform.

Exemple :

```hcl
provisioner "local-exec" {
  command = "echo ${self.public_ip}"
}
```

Nous avons cependant retenu dans les bonnes pratiques qu’il vaut mieux privilégier les mécanismes natifs des providers, `user_data`, les images, cloud-init ou des outils de configuration dédiés avant de dépendre fortement des provisioners.

---

# 15. Terraform State

Le state est une pièce centrale de Terraform.

Par défaut :

```text
terraform.tfstate
```

Il permet de maintenir la correspondance :

```text
Configuration Terraform
        ↕
Terraform State
        ↕
Infrastructure réelle
```

Terraform s’appuie sur cette représentation pour savoir quelles ressources il gère et pour calculer les différences.

Nous avons retenu qu’un state peut contenir des informations sensibles et doit donc être protégé.

---

# 16. Backends et Remote State

Le cours a introduit le backend distant avec AWS S3.

```hcl
terraform {
  backend "s3" {
    bucket = "example-terraform-state"
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
```

Migration d’un state local :

```bash
terraform init -migrate-state
```

Le remote state répond au problème du travail collaboratif :

```text
Développeur A ─┐
Développeur B ─┼──> Backend partagé
CI/CD          ─┘
```

Pour Azure, la suite naturelle identifiée est un backend `azurerm` avec Storage Account / Blob Container sécurisé.

---

# 17. Expressions, `count` et conditions

Le chapitre Remote State introduit également les expressions Terraform.

## `count`

```hcl
resource "aws_instance" "web" {
  count = 3
}
```

Chaque instance peut être adressée via :

```hcl
count.index
```

## `length()`

```hcl
count = length(var.subnets)
```

## Expression ternaire

```hcl
condition ? valeur_si_vrai : valeur_si_faux
```

Exemple :

```hcl
count = var.enable_feature ? 1 : 0
```

Ces mécanismes permettent de rendre la configuration dynamique sans sortir du modèle déclaratif Terraform.

---

# 18. Modules Terraform

Les modules constituent l’un des principaux niveaux de maturité abordés dans le cours.

## 18.1 Root Module

Le dossier depuis lequel Terraform est exécuté est le root module.

## 18.2 Child Modules

Le root module peut appeler plusieurs modules enfants.

```hcl
module "networking" {
  source = "./modules/networking"
}
```

## 18.3 Interface d’un module

```text
variables = entrées
resources = implémentation
outputs   = sorties
```

Architecture typique :

```text
root module
│
├── networking
├── compute
├── database
└── storage
```

Les bénéfices étudiés :

- réutilisabilité ;
- lisibilité ;
- séparation des responsabilités ;
- réduction de duplication ;
- maintenance ;
- standardisation ;
- cohérence entre environnements.

---

# 19. Terraform avec Kubernetes et Helm

Le cours a montré que Terraform ne se limite pas aux machines virtuelles ou aux ressources cloud.

Nous avons étudié l’utilisation de providers permettant de gérer :

- Kubernetes ;
- des Deployments ;
- des Services ;
- des Secrets ;
- Helm et ses releases.

Cela illustre le modèle général de Terraform :

```text
HCL
 ↓
Provider
 ↓
API cible
```

qu’il s’agisse d’AWS, Azure ou Kubernetes.

---

# 20. Projet final officiel — WordPress sur AWS

Le projet final DataScientest demande une infrastructure WordPress construite avec Terraform.

Nous avons transformé cet exercice en un véritable projet exécutable.

Architecture simplifiée :

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
VPC
├── Public Subnet
│      └── EC2 WordPress
│             └── EBS supplémentaire 10 GiB
│
└── Private DB Subnets sur 2 AZ
       └── RDS MySQL Multi-AZ
```

## 20.1 Modules implémentés

```text
modules/
├── networking/
├── ec2/
├── rds/
└── ebs/
```

## 20.2 Exigences couvertes

Nous avons implémenté :

- région `eu-west-3` ;
- EC2 `t3.micro` ;
- AMI Ubuntu dynamique ;
- VPC et subnets ;
- Security Groups ;
- RDS MySQL `db.t3.micro` ;
- Multi-AZ ;
- EBS supplémentaire de 10 GiB ;
- EBS dans la même Availability Zone que l’EC2 ;
- HTTP ;
- HTTPS optionnel ;
- installation automatique de WordPress ;
- variables ;
- outputs ;
- modules ;
- destruction Terraform.

---

# 21. Sécurisation du projet AWS

Nous avons volontairement amélioré le sujet pédagogique.

## 21.1 Aucun mot de passe RDS dans le dépôt

Au lieu de stocker un mot de passe dans `terraform.tfvars`, RDS utilise :

```hcl
manage_master_user_password = true
```

Le secret est ensuite géré par **AWS Secrets Manager**.

## 21.2 Accès du serveur WordPress au secret

```text
EC2
 ↓
IAM Role
 ↓
Permission limitée
 ↓
Secrets Manager
 ↓
Password RDS
```

Le bootstrap WordPress récupère le secret au démarrage.

## 21.3 IMDSv2

La VM impose également l’usage de tokens pour Instance Metadata Service.

---

# 22. Utilisation réelle du volume EBS

Le disque supplémentaire n’est pas seulement déclaré.

Il est :

```text
créé
 ↓
attaché à EC2
 ↓
formaté ext4
 ↓
ajouté à /etc/fstab
 ↓
monté sur
/var/www/html/wp-content/uploads
```

Cela permet de donner une utilité réelle à la contrainte de stockage persistant du projet.

---

# 23. CI GitHub Actions pour le projet AWS

Nous avons ajouté une validation statique automatisée.

Le workflow vérifie :

```text
terraform fmt
terraform init -backend=false
terraform validate
bash -n user_data.sh.tftpl
contrôle simple de clés AWS commitées
```

Un premier run a échoué à cause du formatage HCL. Le code a été corrigé puis la CI est passée au vert.

Cette étape montre un point important : **le code IaC doit être traité avec les mêmes pratiques qualité que le code applicatif**.

---

# 24. Qualification AWS réelle

Nous avons ensuite préparé deux workflows supplémentaires :

```text
terraform-project-final-aws-plan.yml
terraform-project-final-aws-e2e.yml
```

## Workflow AWS Plan

Objectif :

```text
Authentification AWS
      ↓
aws sts get-caller-identity
      ↓
terraform init
      ↓
terraform validate
      ↓
terraform plan réel
```

## Workflow AWS E2E

Objectif :

```text
plan
 ↓
apply
 ↓
contrôles AWS
 ↓
test HTTP WordPress
 ↓
collecte des preuves
 ↓
terraform destroy
```

La qualification AWS réelle est actuellement bloquée uniquement par l’absence d’une identité AWS configurée dans GitHub Actions.

Le workflow privilégie **OIDC** plutôt que des clés AWS longue durée.

---

# 25. Transposition du projet vers Microsoft Azure

Après l’implémentation AWS, nous avons créé une seconde version du projet dans :

```text
Projet_Final/wordpress-azure/
```

L’objectif n’était pas de copier les noms des ressources AWS mais de conserver les mêmes responsabilités architecturales.

## Mapping principal

| AWS | Azure |
|---|---|
| VPC | Virtual Network |
| Subnet | Subnet |
| Security Group | Network Security Group |
| EC2 | Azure Linux Virtual Machine |
| RDS MySQL | Azure Database for MySQL Flexible Server |
| Multi-AZ | ZoneRedundant High Availability |
| EBS | Azure Managed Disk |
| Secrets Manager | Azure Key Vault |
| IAM Role | Managed Identity + Azure RBAC |
| User Data | Custom Data |

---

# 26. Architecture Azure implémentée

```text
Resource Group
   │
   ├── Virtual Network
   │     ├── App Subnet
   │     │     └── Linux VM WordPress
   │     │            └── Managed Disk 10 GiB
   │     │
   │     └── DB Subnet délégué
   │            └── MySQL Flexible Server
   │
   ├── Private DNS Zone
   └── Key Vault
```

Modules créés :

```text
modules/
├── networking/
├── mysql/
├── vm/
└── disk/
```

---

# 27. Sécurisation du projet Azure

Le projet Azure reprend le même principe de séparation des secrets.

```text
Terraform génère le mot de passe MySQL
        ↓
Azure Key Vault
        ↓
Managed Identity de la VM
        ↓
Azure RBAC
        ↓
Bootstrap WordPress
```

Important : le secret généré par Terraform peut toujours être présent dans le Terraform state. Cela renforce la nécessité d’un **backend distant sécurisé** pour un usage réel.

---

# 28. Validation CI de la variante Azure

Un workflow dédié a été ajouté :

```text
.github/workflows/terraform-project-final-azure.yml
```

Le dernier run est passé avec succès sur :

```text
terraform fmt -check -diff -recursive
terraform init -backend=false
terraform validate
bash -n modules/vm/user_data.sh.tftpl
contrôle simple anti-secrets Azure
```

La variante Azure est donc **validée statiquement**, mais n’a pas encore fait l’objet d’un `terraform apply` réel sur une souscription Azure.

---

# 29. Terraform multi-cloud — le principal enseignement

La comparaison AWS / Azure montre que Terraform ne rend pas les clouds identiques.

Terraform standardise surtout le **workflow** :

```text
HCL
 ↓
Provider
 ↓
Plan
 ↓
Apply
 ↓
State
```

En revanche :

```text
AWS Resource Model ≠ Azure Resource Model
```

Les concepts sont souvent comparables mais les implémentations diffèrent.

C’est précisément là que les modules et les abstractions doivent être utilisés avec discernement : il ne faut pas essayer de cacher toutes les différences entre clouds au prix d’une abstraction artificielle.

---

# 30. Bonnes pratiques retenues

À travers le cours et les projets, nous avons consolidé les pratiques suivantes :

1. Versionner les fichiers `.tf`.
2. Conserver `.terraform.lock.hcl`.
3. Ne jamais versionner `terraform.tfstate`.
4. Utiliser un backend distant pour le travail collaboratif.
5. Ne pas coder les secrets en dur.
6. Préférer des identités temporaires / fédérées dans la CI.
7. Utiliser `terraform fmt` et `terraform validate` systématiquement.
8. Lire le `terraform plan` avant un `apply`.
9. Paramétrer les projets avec des variables.
10. Utiliser des data sources pour éviter les identifiants statiques lorsque pertinent.
11. Exposer les informations importantes avec des outputs.
12. Structurer les architectures complexes avec des modules.
13. Garder les modules cohérents et centrés sur une responsabilité claire.
14. Utiliser les références Terraform pour exprimer les dépendances naturellement.
15. Réserver `depends_on` aux dépendances qui ne peuvent pas être déduites.
16. Éviter de dépendre excessivement des provisioners.
17. Tester également les scripts de bootstrap.
18. Ajouter la CI dès qu’un projet Terraform devient significatif.
19. Détruire proprement les environnements de laboratoire avec Terraform.
20. Traiter le state comme une donnée sensible.

---

# 31. Anti-patterns identifiés

Nous avons également identifié plusieurs erreurs classiques :

```text
credentials en dur
AMI codée en dur sans nécessité
state versionné dans Git
un seul énorme main.tf
usage excessif de depends_on
usage systématique des provisioners
aucune validation des variables
aucun terraform plan avant apply
aucune politique de version provider
modification manuelle des ressources hors Terraform
oubli de terraform destroy dans un lab
```

Ces anti-patterns rendent l’infrastructure difficile à reproduire, à maintenir et à auditer.

---

# 32. Livrables documentaires produits

Le module Terraform est maintenant documenté sur plusieurs couches.

## Cours restructurés

```text
192.01_TERRAFORM_INTRODUCTION_ET_INSTALLATION.md
192.02_TERRAFORM_HCL_PROVIDERS_ET_RESOURCES.md
192.03_TERRAFORM_VARIABLES_OUTPUTS_ET_DEPENDANCES.md
192.04_TERRAFORM_USER_DATA_PROVISIONERS_DATA_SOURCES.md
192.05_TERRAFORM_STATE_BACKENDS_EXPRESSIONS.md
192.06_TERRAFORM_MODULES_ET_ARCHITECTURE_MODULAIRE.md
192.07_TERRAFORM_CONCLUSION_ET_PROJET_FINAL.md
```

## Références

```text
HCL
Providers
Resources / Data Sources
Variables
Outputs
Dépendances
Provisioners
State / Backends
Expressions / Count / Conditions
Modules
Commandes
```

## Synthèses

```text
Synthèse complète
Architecture & Workflow
Workflow init/plan/apply/destroy
Architecture AWS
Kubernetes & Helm
State & Collaboration
Modules & Réutilisabilité
Best Practices
Anti-patterns & Pièges
Compétences à retenir
```

## Projets finaux

```text
wordpress-aws/
wordpress-azure/
```

---

# 33. Compétences acquises

À l’issue de ce bloc, les compétences travaillées peuvent être regroupées ainsi.

## Compréhension conceptuelle

- expliquer l’Infrastructure as Code ;
- distinguer configuration, state et infrastructure réelle ;
- comprendre Terraform Core et providers ;
- comprendre le fonctionnement déclaratif de Terraform.

## HCL

- écrire des blocs et arguments ;
- référencer des ressources ;
- manipuler variables, locals et outputs ;
- écrire des expressions conditionnelles ;
- utiliser `count`.

## Providers et ressources

- configurer un provider ;
- gérer ses versions ;
- créer des ressources ;
- utiliser des data sources.

## Workflow

- utiliser `fmt` ;
- initialiser avec `init` ;
- valider ;
- produire un plan ;
- appliquer ;
- consulter les outputs ;
- détruire.

## State

- comprendre `terraform.tfstate` ;
- migrer vers un backend distant ;
- comprendre les enjeux collaboratifs et de sécurité.

## Modularité

- créer un root module ;
- créer des child modules ;
- définir des interfaces via variables et outputs ;
- découper une architecture par responsabilité.

## Cloud

- automatiser une architecture AWS ;
- transposer cette architecture vers Azure ;
- comprendre que Terraform standardise le workflow mais pas les services cloud.

## DevOps

- intégrer Terraform dans GitHub Actions ;
- automatiser les validations ;
- sécuriser les credentials ;
- préparer une qualification end-to-end ;
- produire des preuves de validation.

---

# 34. Ce qu’il reste encore à qualifier réellement

Le bloc Terraform est très avancé, mais deux qualifications cloud réelles restent distinctes de la validation statique.

## AWS

À réaliser dès qu’une identité AWS est disponible :

```text
OIDC GitHub → AWS
terraform plan réel
terraform apply
validation EC2
validation EBS
validation RDS Multi-AZ
validation WordPress HTTP
collecte des preuves
terraform destroy
```

## Azure

À préparer ensuite :

```text
OIDC GitHub → Azure
terraform plan réel
terraform apply
validation VM
validation Managed Disk
validation MySQL Flexible Server
validation Key Vault / Managed Identity
validation WordPress HTTP
collecte des preuves
terraform destroy
```

---

# 35. Ce que Terraform apporte dans le Sprint 17

Terraform répond principalement au besoin de **provisioning d’infrastructure**.

```text
Terraform
    ↓
Provisionner
    ↓
réseau
compute
storage
database
services cloud
```

Le rôle d’Ansible, étudié dans l’autre moitié du Sprint 17, sera davantage orienté :

```text
Ansible
   ↓
Configurer
   ↓
packages
fichiers
services
applications
```

La complémentarité conceptuelle du Sprint 17 est donc :

```text
Terraform
Provision infrastructure
        ↓
Infrastructure disponible
        ↓
Ansible
Configure infrastructure / applications
```

---

# 36. Conclusion générale

Le module Terraform a permis de progresser d’une découverte de l’Infrastructure as Code jusqu’à une vision beaucoup plus complète de l’automatisation d’infrastructure.

La progression réellement obtenue est :

```text
Comprendre IaC
      ↓
Écrire du HCL
      ↓
Utiliser des providers
      ↓
Créer des resources
      ↓
Paramétrer avec variables
      ↓
Interroger avec data sources
      ↓
Gérer outputs et dépendances
      ↓
Automatiser le bootstrap
      ↓
Comprendre le state
      ↓
Passer au remote state
      ↓
Créer des configurations dynamiques
      ↓
Construire des modules
      ↓
Déployer une architecture AWS complète
      ↓
Industrialiser avec GitHub Actions
      ↓
Préparer une qualification cloud réelle
      ↓
Transposer l’architecture vers Azure
```

Le principal acquis n’est donc pas seulement de savoir écrire quelques ressources Terraform. Il est de comprendre **comment transformer une architecture cloud en un système déclaratif, versionné, paramétrable, modulaire, testable et reproductible**.

C’est ce qui constitue le véritable objectif du bloc Terraform dans le Sprint 17 — Automatisation.

---

## Documents à consulter en priorité

Pour réviser rapidement après ce bilan :

```text
192_TERRAFORM_SYNTHESE_COMPLETE.md
192_TERRAFORM_ARCHITECTURE_AND_WORKFLOW.md
Reference/192_TERRAFORM_COMMANDES_REFERENCE.md
Reference/192_TERRAFORM_STATE_BACKENDS_REFERENCE.md
Reference/192_TERRAFORM_MODULES_REFERENCE.md
Synthese/192_TERRAFORM_BEST_PRACTICES.md
Synthese/192_TERRAFORM_ANTI_PATTERNS_ET_PIEGES.md
Projet_Final/README.md
```
