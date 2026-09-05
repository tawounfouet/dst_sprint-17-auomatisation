# 192 — Terraform DevOps — Synthèse complète

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Synthèse transversale des chapitres 192.01 à 192.07

## 1. Vue d’ensemble

Terraform est un outil d’**Infrastructure as Code (IaC)** permettant de décrire une infrastructure sous forme de configuration, puis de créer, modifier ou supprimer les ressources nécessaires pour rapprocher l’infrastructure réelle de l’état souhaité.

Le module DataScientest construit progressivement cette compétence selon la chaîne suivante :

```text
Infrastructure as Code
        ↓
HCL
        ↓
Providers
        ↓
Resources / Data Sources
        ↓
Variables / Outputs / Dépendances
        ↓
User Data / Provisioners
        ↓
State / Backends
        ↓
Expressions
        ↓
Modules
        ↓
Architecture AWS complète
```

Le fil rouge du cours consiste à passer d’une infrastructure simple et codée en dur à une architecture **paramétrable, dynamique, partageable et modulaire**.

---

## 2. Infrastructure as Code

### 2.1 Principe

L’Infrastructure as Code consiste à gérer l’infrastructure avec des fichiers de configuration versionnables plutôt qu’avec des actions exclusivement manuelles.

```text
Approche manuelle
Console → clics → infrastructure

Approche IaC
Code → outil IaC → infrastructure
```

### 2.2 Bénéfices principaux

Le cours met en avant :

- réduction des erreurs humaines ;
- rapidité de création des environnements ;
- reproductibilité ;
- cohérence entre environnements ;
- versionnement ;
- traçabilité ;
- automatisation ;
- meilleure collaboration entre équipes.

### 2.3 Idempotence

L’idempotence signifie que la configuration décrit un état cible. Terraform calcule ensuite les différences entre l’état connu et l’état souhaité.

```text
Configuration désirée
        ↓
Comparaison
        ↓
Différences
        ↓
Actions minimales nécessaires
```

---

## 3. Architecture de Terraform

Terraform repose sur deux grandes briques :

```text
Terraform Core
      │
      └── Provider
             │
             └── API cible
```

### 3.1 Terraform Core

Terraform Core :

- lit les fichiers `.tf` ;
- analyse les expressions ;
- construit les dépendances ;
- lit et met à jour le state ;
- génère le plan d’exécution ;
- orchestre la création, modification et suppression des ressources.

### 3.2 Providers

Un provider est un plugin qui traduit les opérations Terraform en appels vers une API externe.

Exemples utilisés ou cités dans le cours :

- AWS ;
- Kubernetes ;
- Helm ;
- Azure ;
- GCP ;
- Docker ;
- GitLab ;
- DigitalOcean ;
- OpenStack ;
- OVH.

Le provider est donc l’interface entre Terraform et la plateforme gérée.

---

## 4. HCL — HashiCorp Configuration Language

Terraform utilise principalement **HCL**, un langage de configuration conçu pour être lisible par l’humain.

### 4.1 Arguments

```hcl
name = "datascientest"
```

Un argument associe un identifiant à une expression.

### 4.2 Blocs

```hcl
resource "aws_instance" "web" {
  ami           = "ami-..."
  instance_type = "t3.micro"
}
```

Forme générale :

```text
<TYPE_DE_BLOC> "<LABEL_1>" "<LABEL_2>" {
  argument = expression
}
```

### 4.3 Commentaires

HCL accepte notamment :

```hcl
# commentaire
// commentaire
/* commentaire
   multiligne */
```

### 4.4 Identifiants

Les identifiants peuvent contenir lettres, chiffres, `_` et `-`, mais ne doivent pas commencer par un chiffre.

---

## 5. Providers et versions

Une configuration AWS minimale :

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}
```

Le cours insiste sur la déclaration des contraintes de versions dans `required_providers`, plutôt que dans le bloc `provider`.

### 5.1 Contraintes de version

Exemples :

```hcl
version = "= 2.9.0"
version = ">= 2.9.0"
version = "<= 2.9.0"
version = ">= 1.2.0, < 2.0.0"
version = "~> 2.9.0"
```

L’opérateur `~>` autorise l’évolution compatible du composant situé à droite selon la contrainte exprimée.

### 5.2 Lock file

Après `terraform init`, Terraform peut générer :

```text
.terraform.lock.hcl
```

Ce fichier mémorise les versions de providers sélectionnées et doit être conservé pour améliorer la reproductibilité.

---

## 6. Commandes Terraform

### 6.1 `terraform init`

Prépare le répertoire de travail :

- initialise le backend ;
- télécharge les providers ;
- télécharge les modules si nécessaire.

```bash
terraform init
```

### 6.2 `terraform fmt`

Formate le code HCL :

```bash
terraform fmt
```

### 6.3 `terraform validate`

Vérifie la validité de la configuration :

```bash
terraform validate
```

### 6.4 `terraform plan`

Affiche les changements prévus sans les appliquer :

```bash
terraform plan
```

Exemple de résumé :

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

### 6.5 `terraform apply`

Applique le plan :

```bash
terraform apply
```

ou dans les exercices :

```bash
terraform apply -auto-approve
```

### 6.6 `terraform destroy`

Supprime les ressources gérées par la configuration :

```bash
terraform destroy -auto-approve
```

Le cours rappelle régulièrement que les ressources créées par Terraform doivent être détruites avec Terraform.

---

## 7. Resources

Une `resource` représente un objet que Terraform doit créer ou gérer.

Exemples AWS :

- `aws_instance` ;
- `aws_vpc` ;
- `aws_subnet` ;
- `aws_security_group` ;
- `aws_ebs_volume` ;
- `aws_db_instance`.

Exemples Kubernetes :

- deployment ;
- service ;
- secret.

Exemple :

```hcl
resource "aws_instance" "web" {
  ami           = var.image_id
  instance_type = var.instance_type

  tags = {
    Name = "datascientest"
  }
}
```

Une ressource se référence sous la forme :

```text
TYPE.NOM.ATTRIBUT
```

Exemple :

```hcl
aws_instance.web.id
```

---

## 8. Dépendances entre ressources

Terraform construit automatiquement un graphe de dépendances lorsque des ressources se référencent entre elles.

Exemple :

```hcl
resource "aws_volume_attachment" "data" {
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}
```

Terraform comprend ici que le volume et l’instance doivent exister avant l’attachement.

### 8.1 Dépendance explicite

Si une dépendance ne peut pas être déduite :

```hcl
depends_on = [
  aws_security_group.web
]
```

Le cours recommande de réserver `depends_on` aux situations où la dépendance ne peut pas être exprimée naturellement par les références.

---

## 9. Variables d’entrée

Les variables rendent une configuration réutilisable.

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
```

Utilisation :

```hcl
instance_type = var.instance_type
```

### 9.1 Arguments principaux

Le cours présente :

- `type` ;
- `default` ;
- `description` ;
- `validation` ;
- `sensitive` ;
- `nullable`.

### 9.2 Validation

```hcl
variable "image_id" {
  type = string

  validation {
    condition     = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
    error_message = "L'identifiant doit commencer par ami-."
  }
}
```

### 9.3 Variables sensibles

```hcl
variable "password" {
  type      = string
  sensitive = true
}
```

Important : `sensitive = true` masque l’affichage dans le CLI, mais le cours rappelle que la valeur peut toujours être présente dans le state.

### 9.4 Nullable

```hcl
variable "image_id" {
  type     = string
  nullable = false
}
```

---

## 10. Affectation des variables

Plusieurs mécanismes sont présentés.

### Valeur par défaut

```hcl
default = "t3.micro"
```

### Ligne de commande

```bash
terraform apply -var="instance_type=t3.micro"
```

### Fichier `terraform.tfvars`

```hcl
instance_type = "t3.micro"
monitoring    = true
```

### Fichier personnalisé

```bash
terraform apply -var-file="production.tfvars"
```

### Variables d’environnement

```bash
export TF_VAR_instance_type=t3.micro
```

---

## 11. Locals

Les valeurs locales permettent de centraliser des valeurs ou expressions internes au module.

```hcl
locals {
  environment   = "prod"
  project       = "datascientest"
  resource_name = "${local.project}-${local.environment}"
}
```

Le cours les utilise notamment pour mutualiser les labels Kubernetes.

---

## 12. Outputs

Les outputs exposent les informations importantes produites par Terraform.

```hcl
output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
```

Consultation :

```bash
terraform output
```

Arguments présentés :

- `description` ;
- `sensitive` ;
- `depends_on`.

Les outputs constituent également l’interface de sortie d’un module.

---

## 13. Data Sources

Une data source permet de **lire une information existante** depuis l’API d’un provider.

Exemple du cours : rechercher dynamiquement une AMI Amazon Linux au lieu de coder son identifiant en dur.

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}
```

Puis :

```hcl
ami = data.aws_ami.amazon_linux.id
```

La distinction fondamentale est :

```text
resource = gérer/créer

data     = lire/interroger
```

---

## 14. User Data

Sur une instance EC2, `user_data` permet d’exécuter un script au démarrage initial.

Exemple :

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  user_data     = file("install_apache.sh")
}
```

`install_apache.sh` peut installer et démarrer un serveur web.

Le cours présente deux formes :

- heredoc directement dans le HCL ;
- fichier externe chargé avec `file()`.

La seconde sépare mieux le code d’infrastructure du script de bootstrap.

---

## 15. Provisioners

Les provisioners permettent d’exécuter des actions complémentaires associées au cycle de vie d’une ressource.

Le cours présente :

- `local-exec` ;
- `remote-exec` ;
- `file`.

### 15.1 `local-exec`

Exécuté sur la machine qui lance Terraform :

```hcl
provisioner "local-exec" {
  command = "echo ${self.public_ip} >> public_ip.txt"
}
```

### 15.2 `file`

Copie un fichier sur une machine distante.

### 15.3 `remote-exec`

Exécute des commandes sur une ressource distante, généralement via SSH.

### 15.4 `self`

Dans un provisioner :

```hcl
self.public_ip
```

représente l’attribut de la ressource parente.

### 15.5 `when` et `on_failure`

Le cours présente également :

```hcl
when = destroy
```

et :

```hcl
on_failure = continue
```

Les provisioners servent principalement aux opérations complémentaires ou aux intégrations avec d’autres outils de configuration.

---

## 16. Terraform State

Terraform conserve une représentation des ressources qu’il gère dans son **state**.

Par défaut :

```text
terraform.tfstate
```

Le state établit les correspondances entre :

```text
Configuration Terraform
        ↕
Terraform State
        ↕
Objets distants
```

Le cours indique que le state est stocké au format JSON.

### 16.1 Backend local

Sans configuration spécifique, le state est conservé localement.

Un backend local explicite peut également définir un autre chemin.

### 16.2 Limite du state local

Pour un travail d’équipe :

```text
Développeur A → state A
Développeur B → state B
```

n’est pas une organisation satisfaisante.

Le state doit être partagé.

---

## 17. Remote State avec S3

Le cours configure un backend AWS S3.

```hcl
terraform {
  backend "s3" {
    bucket = "example-terraform-state"
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
```

Lors du passage du backend local au backend distant :

```bash
terraform init -migrate-state
```

Architecture :

```text
Équipe
  ↓
Code Terraform
  ↓
Terraform
  ↓
Backend S3
  ↓
State partagé
```

Le backend devient donc une composante essentielle de l’usage collaboratif de Terraform.

---

## 18. `count`

`count` permet de créer plusieurs instances d’une même ressource.

```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = var.image_id
  instance_type = var.instance_type
}
```

La ressource n’est alors plus traitée comme un objet unique, mais comme une collection indexée.

Référence :

```hcl
aws_instance.web[0].id
aws_instance.web[1].id
```

### 18.1 `count.index`

```hcl
tags = {
  Name = "datascientest-${count.index}"
}
```

### 18.2 Accès à plusieurs attributs

Le cours montre qu’après ajout de `count`, toutes les références doivent être adaptées à la cardinalité de la ressource.

---

## 19. `length()`

`length()` retourne la taille d’une collection.

```hcl
count = length(aws_instance.web)
```

Le cours l’utilise pour créer autant de volumes EBS ou d’attachements qu’il existe d’instances.

---

## 20. Conditions

Terraform utilise les expressions conditionnelles :

```text
condition ? valeur_si_vrai : valeur_si_faux
```

Exemple :

```hcl
count = var.environment == "dev" ? 1 : 3
```

Donc :

```text
dev  → 1 instance
autre → 3 instances
```

Terraform ne repose pas sur une logique `if` procédurale classique ; le cours illustre comment combiner expressions conditionnelles et méta-arguments.

---

## 21. Kubernetes avec Terraform

Le cours utilise un cluster **k3s** pour montrer que Terraform ne se limite pas aux ressources cloud.

Le provider Kubernetes permet de créer :

- secrets ;
- deployments ;
- services.

Exemple de workflow :

```text
Terraform
  ↓
Provider Kubernetes
  ↓
API Server Kubernetes
  ↓
Deployment WordPress + MySQL
```

Le cours valide ensuite les ressources avec `kubectl get all`.

---

## 22. Helm avec Terraform

Le provider Helm permet de déployer des charts sur Kubernetes.

Le cours construit des charts WordPress et MySQL, puis utilise :

```hcl
resource "helm_release" "mysql" {
  name      = "mysql"
  namespace = "wordpress"
  chart     = "${path.module}/mysql-chart"
}
```

et une seconde release WordPress dépendante de MySQL.

Cela montre que Terraform peut orchestrer des outils spécialisés comme Helm tout en conservant une configuration globale de l’infrastructure.

---

## 23. Modules Terraform

Un module est un ensemble de fichiers Terraform regroupés dans un répertoire.

### 23.1 Module racine

Le répertoire depuis lequel Terraform est exécuté.

### 23.2 Module enfant

Module appelé depuis une autre configuration.

### 23.3 Structure minimale recommandée dans le cours

```text
module/
├── README.md
├── main.tf
├── variables.tf
└── outputs.tf
```

### 23.4 Appel d’un module local

```hcl
module "ec2" {
  source = "./modules/ec2"
}
```

### 23.5 Module du Registry

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
}
```

---

## 24. Pourquoi modulariser ?

Le cours met en avant :

- maintenabilité ;
- réutilisabilité ;
- navigation plus simple ;
- cohérence des environnements ;
- réduction de la dérive ;
- meilleure organisation du code.

Architecture pédagogique :

```text
Root Module
│
├── networking
│   ├── VPC
│   ├── subnets
│   ├── NAT Gateway
│   └── security groups
│
└── ec2
    ├── instance publique
    ├── instance privée
    ├── user_data
    └── outputs
```

---

## 25. Projet final WordPress AWS

Le projet final demande de déployer automatiquement une infrastructure WordPress sur AWS.

### 25.1 Contraintes principales

- région `eu-west-3` ;
- instance EC2 `t3.micro` ;
- récupération automatique de l’AMI ;
- récupération des Availability Zones ;
- base de données via `aws_db_instance` ;
- déploiement dans deux Availability Zones ;
- EBS supplémentaire de 10 Go ;
- EC2 et EBS dans la même Availability Zone ;
- port HTTP 80 ;
- HTTPS/TLS en bonus ;
- architecture segmentée en modules ;
- aucun mot de passe en dur ;
- infrastructure répétable et réutilisable.

### 25.2 Découpage attendu

```text
modules/
├── networking/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ec2/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── rds/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── ebs/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

Root module :

```text
├── main.tf
├── variables.tf
└── install_wordpress.sh
```

---

## 26. Chaîne de maturité suivie par le cours

Le module peut être compris comme une montée en maturité :

```text
1. Ressource codée en dur
        ↓
2. Provider versionné
        ↓
3. Variables
        ↓
4. Références et dépendances
        ↓
5. Data sources
        ↓
6. Bootstrap automatique
        ↓
7. State distant
        ↓
8. Ressources dynamiques
        ↓
9. Modules
        ↓
10. Architecture complète
```

---

## 27. Fichiers Terraform et rôles

| Fichier | Rôle habituel dans le module |
|---|---|
| `main.tf` | ressources principales / appels de modules |
| `provider.tf` | providers et contraintes associées |
| `variables.tf` | définition des entrées |
| `terraform.tfvars` | valeurs des variables |
| `outputs.tf` | sorties |
| `security.tf` | groupes de sécurité / attachements |
| `ebs.tf` | volumes / attachements |
| `install_*.sh` | bootstrap des machines |
| `.terraform.lock.hcl` | verrouillage des versions de providers |
| `terraform.tfstate` | état Terraform lorsqu’il est local |

Le découpage par fichiers est une convention d’organisation : Terraform charge les fichiers `.tf` du répertoire comme une même configuration de module.

---

## 28. Points de vigilance explicitement rencontrés dans le cours

### Secrets

Ne pas coder durablement :

```hcl
access_key = "..."
secret_key = "..."
password   = "..."
```

Le chapitre modules montre l’usage de variables d’environnement AWS pour ne pas exposer les accès dans le code.

### State

Une variable marquée `sensitive` peut toujours se retrouver dans le state.

### `count`

Après ajout de `count`, une ressource devient une collection ; les références singulières précédentes doivent être corrigées.

### Availability Zone

Un volume EBS doit être attaché à une instance située dans une zone compatible, le cours impose donc une cohérence de zone.

### Dépendances

Préférer les références naturelles ; utiliser `depends_on` uniquement lorsque Terraform ne peut pas déduire la relation.

### Nettoyage

Toujours détruire les ressources des exercices avec :

```bash
terraform destroy --auto-approve
```

---

## 29. Workflow de qualité à retenir

```text
Code
 ↓
terraform fmt
 ↓
terraform init
 ↓
terraform validate
 ↓
terraform plan
 ↓
Revue
 ↓
terraform apply
 ↓
Tests fonctionnels
 ↓
terraform output / vérifications provider
 ↓
terraform destroy si nécessaire
```

---

## 30. Compétences à retenir

À l’issue du module, il faut savoir :

1. expliquer l’IaC ;
2. installer Terraform ;
3. écrire du HCL ;
4. configurer et versionner des providers ;
5. créer des resources ;
6. utiliser des variables et `.tfvars` ;
7. définir des outputs ;
8. relier les ressources via leurs attributs ;
9. comprendre les dépendances ;
10. utiliser `user_data` ;
11. comprendre les provisioners ;
12. interroger des data sources ;
13. comprendre `terraform.tfstate` ;
14. migrer vers un backend S3 ;
15. utiliser `count`, `count.index` et `length()` ;
16. écrire une condition ternaire ;
17. construire des modules ;
18. consommer un module du Registry ;
19. structurer une architecture AWS en plusieurs modules ;
20. tester et nettoyer une infrastructure Terraform.

---

## 31. Résumé en une phrase

> Terraform permet de transformer une infrastructure en **configuration déclarative, versionnable, reproductible et modulaire**, puis d’en gérer le cycle de vie à travers des providers, un state et un workflow `init → plan → apply → destroy`.

---

## 32. Sources pédagogiques

Cette synthèse est construite à partir des sept supports du module Terraform DataScientest du Sprint 17 :

- Introduction et installation ;
- Le langage HCL et providers ;
- Variables d’entrée ;
- Données utilisateurs et sources de données ;
- Remote State ;
- Les modules ;
- Conclusion et projet final.

Les identifiants de connexion et secrets présents dans certains supports pédagogiques ne sont volontairement pas reproduits dans ce document.