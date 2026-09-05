# Terraform — Architecture AWS

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Type : Synthèse d’architecture

## 1. Objectif

Ce document synthétise les éléments AWS manipulés dans les supports Terraform DataScientest et les replace dans une architecture cohérente.

Les chapitres utilisent progressivement Terraform pour piloter :

- des instances EC2 ;
- des VPC et subnets ;
- des interfaces réseau ;
- des Security Groups ;
- des volumes EBS ;
- des AMI récupérées dynamiquement ;
- des outputs ;
- un backend S3 ;
- des modules ;
- puis, dans le projet final, une architecture WordPress comprenant également RDS.

---

## 2. Vue d’ensemble

```text
                    AWS eu-west-3
                         │
                      VPC
                         │
             ┌───────────┴───────────┐
             │                       │
      Public Subnet(s)        Private Subnet(s)
             │                       │
          EC2 Web                 EC2 / RDS
             │                       │
       Security Group         Security Group
             │
          EBS Volume
```

Dans le projet final, le serveur web WordPress doit être accessible en HTTP, avec HTTPS en bonus, tandis que la base de données doit être déployée avec la ressource `aws_db_instance` sur deux Availability Zones.

---

## 3. Provider AWS

Le point d’entrée Terraform vers AWS est le provider :

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

Les supports montrent parfois des clés directement dans le bloc provider pour les besoins du lab. Les documents restructurés du dépôt n’en reprennent pas les valeurs.

Pour la suite du cours, les credentials sont plutôt externalisés via l’environnement :

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

---

## 4. EC2 — Ressource de calcul

Une instance EC2 est créée avec `aws_instance`.

Exemple simplifié :

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  tags = {
    Name = "web"
  }
}
```

Les supports font évoluer cet exemple avec :

- `monitoring` ;
- `key_name` ;
- `user_data` ;
- une interface réseau ;
- un Security Group ;
- un EBS ;
- plusieurs instances via `count` ;
- puis une intégration dans des modules.

---

## 5. AMI dynamique avec une Data Source

L’un des problèmes identifiés dans le cours est le codage en dur d’un ID d’AMI, valable seulement pour une région donnée.

La réponse consiste à interroger AWS avec une Data Source :

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
resource "aws_instance" "web" {
  ami = data.aws_ami.amazon_linux.id
}
```

Le principe est important :

```text
Valeur statique codée en dur
          ↓
Data Source
          ↓
Valeur récupérée depuis l’API AWS
```

---

## 6. VPC et sous-réseaux

Le cours crée un VPC avec `aws_vpc` :

```hcl
resource "aws_vpc" "main" {
  cidr_block = "172.16.0.0/16"
}
```

Puis un subnet :

```hcl
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "eu-west-3a"
}
```

La référence :

```hcl
vpc_id = aws_vpc.main.id
```

crée une **dépendance implicite** entre le subnet et le VPC.

---

## 7. Interface réseau

Le cours montre également `aws_network_interface` :

```hcl
resource "aws_network_interface" "web" {
  subnet_id   = aws_subnet.main.id
  private_ips = ["172.16.10.100"]
}
```

Puis cette interface peut être utilisée par une instance EC2 :

```hcl
network_interface {
  network_interface_id = aws_network_interface.web.id
  device_index         = 0
}
```

---

## 8. Security Groups

Les Security Groups contrôlent les flux réseau autorisés.

Le support crée notamment des règles d’entrée pour :

- HTTP : port 80 ;
- HTTPS : port 443 ;
- SSH : port 22.

Exemple condensé :

```hcl
resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Le cours propose aussi un `aws_network_interface_sg_attachment` pour associer un Security Group à une interface réseau.

---

## 9. EBS — Stockage persistant

Le cours introduit un disque EBS :

```hcl
resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone[0]
  size              = var.ebs_size
}
```

Puis l’attache à une instance :

```hcl
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}
```

Le point pédagogique essentiel est que :

> **L’instance EC2 et le volume EBS doivent être dans la même Availability Zone pour pouvoir être attachés.**

Dans le projet final, le volume demandé fait **10 Go**.

---

## 10. `user_data` — Bootstrap du serveur web

Les supports utilisent `user_data` pour automatiser la configuration initiale d’une instance.

Exemple :

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  user_data     = file("install_apache.sh")
}
```

Le script peut installer Apache ou WordPress au premier démarrage.

```text
EC2 créée
   ↓
user_data exécuté
   ↓
Packages installés
   ↓
Service démarré
   ↓
Application disponible
```

---

## 11. RDS dans le projet final

Le projet final demande explicitement une base de données utilisant :

```text
aws_db_instance
```

avec un type :

```text
db.t3.micro
```

et un déploiement dans **deux Availability Zones différentes** de `eu-west-3`.

Le support final ne fournit pas la solution complète : il demande à l’apprenant de construire ce module et de s’appuyer sur la documentation de la ressource.

L’architecture cible comprend donc au minimum :

```text
WordPress EC2
      │
      ↓
     RDS
```

avec la base protégée par la couche réseau appropriée.

---

## 12. Backend S3

AWS n’est pas seulement utilisé comme plateforme cible : le cours utilise aussi S3 pour stocker le **state Terraform à distance**.

```hcl
terraform {
  backend "s3" {
    bucket = "..."
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
```

Cela transforme AWS en composant du plan de contrôle Terraform :

```text
Code Terraform
     │
     ├── Provider AWS → ressources AWS
     │
     └── Backend S3 → state partagé
```

---

## 13. Architecture modulaire vue dans le cours

Le chapitre sur les modules sépare l’infrastructure en deux briques principales :

```text
Root Module
│
├── networking
│   ├── VPC
│   ├── subnets publics
│   ├── subnets privés
│   ├── NAT Gateway
│   └── Security Groups
│
└── ec2
    ├── EC2 publique
    ├── EC2 privée
    ├── user_data
    └── outputs
```

Le module `networking` appelle lui-même le module Registry :

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
}
```

---

## 14. Architecture cible du projet final

Le sujet final demande une segmentation :

```text
modules/
├── networking/
├── ec2/
├── rds/
└── ebs/
```

On peut la représenter ainsi :

```text
                    Root Module
                         │
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
   networking           ec2              rds
        │                │                │
       VPC             Web EC2         Database
     Subnets             │            Multi-AZ
       SG                │
        │                ↓
        └────────────── ebs
                         │
                       10 Go
```

---

## 15. Variables et outputs utiles

Le cours encourage la paramétrisation de valeurs telles que :

```text
region
instance_type
ebs_size
namespace
availability_zone
CIDR VPC
CIDR subnet
monitoring
```

Les outputs permettent ensuite d’exposer des données clés :

```hcl
output "public_ip" {
  value = aws_instance.web.public_ip
}
```

---

## 16. Dépendances principales

Une architecture AWS Terraform forme naturellement un graphe :

```text
VPC
 ↓
Subnet
 ↓
Network Interface
 ↓
EC2
 ↓
EBS Attachment
```

En parallèle :

```text
VPC
 ↓
Security Group
 ↓
EC2 / Network Interface
```

Terraform déduit ces dépendances à partir des références d’attributs.

---

## 17. Compétences d’architecture à retenir

À partir des supports, il faut être capable de :

- déclarer le provider AWS ;
- créer une instance EC2 ;
- récupérer une AMI dynamiquement ;
- construire un VPC et un subnet ;
- créer et associer un Security Group ;
- créer et attacher un volume EBS ;
- automatiser le bootstrap avec `user_data` ;
- utiliser un backend S3 ;
- segmenter l’infrastructure en modules ;
- exposer les informations utiles via des outputs ;
- construire le projet final EC2 + RDS + EBS + networking.

---

## Source pédagogique

Synthèse fondée sur les supports Terraform DataScientest du Sprint 17, en particulier les chapitres Variables, User Data et Data Sources, Remote State, Modules, ainsi que le sujet du projet final WordPress AWS.