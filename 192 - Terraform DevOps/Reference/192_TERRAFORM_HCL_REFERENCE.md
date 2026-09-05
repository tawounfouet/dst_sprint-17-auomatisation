# 192 — Terraform HCL Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Référence issue du chapitre **192.02 — HCL, providers et ressources**.

## 1. Rôle de HCL

Terraform utilise **HCL — HashiCorp Configuration Language** pour décrire l’infrastructure. Le support DataScientest le présente comme un langage lisible, concis et souple sur l’indentation, conçu pour structurer une configuration Terraform en fichiers `.tf`.

Terraform accepte également une représentation JSON, mais le cours privilégie HCL pour sa lisibilité humaine.

---

## 2. Structure générale

La syntaxe Terraform repose principalement sur :

- des **arguments** ;
- des **blocs** ;
- des **identifiants** ;
- des **expressions** ;
- des **commentaires**.

### Argument

```hcl
name = "Datascientest-namespace"
```

Forme générale :

```text
IDENTIFIANT = EXPRESSION
```

### Bloc

```hcl
resource "kubernetes_namespace" "datascientest_namespace" {
  metadata {
    labels = {
      app = "datascientest-namespace"
    }

    name = "datascientest-namespace"
  }
}
```

Forme générale :

```text
TYPE_DE_BLOC "LABEL_1" "LABEL_2" {
  ARGUMENT = EXPRESSION

  BLOC_IMBRIQUE {
    ...
  }
}
```

---

## 3. Blocs courants vus dans le cours

### `terraform`

Utilisé notamment pour déclarer les providers requis et les backends.

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

### `provider`

Configure un provider.

```hcl
provider "aws" {
  region = "eu-west-3"
}
```

### `resource`

Déclare une ressource à gérer.

```hcl
resource "aws_instance" "web" {
  ami           = var.image_id
  instance_type = var.type_instance
}
```

### `data`

Lit une information existante depuis un provider.

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}
```

### `variable`

Déclare une variable d’entrée.

```hcl
variable "environment" {
  type    = string
  default = "dev"
}
```

### `locals`

Déclare des valeurs locales réutilisables dans le module.

```hcl
locals {
  project     = "datascientest"
  environment = "prod"
}
```

### `output`

Expose une valeur utile après déploiement.

```hcl
output "instance_ip" {
  value = aws_instance.web.public_ip
}
```

### `module`

Appelle un module enfant.

```hcl
module "networking" {
  source    = "./modules/networking"
  namespace = var.namespace
}
```

---

## 4. Identifiants

Le support indique que les identifiants peuvent contenir :

- lettres ;
- chiffres ;
- `_` ;
- `-`.

Le premier caractère ne doit pas être un chiffre.

Les identifiants sont utilisés notamment pour :

- noms de variables ;
- noms de ressources ;
- noms de modules ;
- attributs ;
- types de blocs.

---

## 5. Commentaires

Trois formes sont présentées dans le cours :

```hcl
# commentaire
```

```hcl
// commentaire
```

```hcl
/*
commentaire
multiligne
*/
```

Le support recommande principalement `#` pour les commentaires usuels.

---

## 6. Références

Terraform permet de référencer des objets déclarés ailleurs dans la configuration.

### Variable

```hcl
var.image_id
```

### Ressource

```hcl
aws_instance.web.id
```

### Data source

```hcl
data.aws_ami.amazon_linux.id
```

### Local

```hcl
local.environment
```

### Module

```hcl
module.networking.vpc
```

---

## 7. Interpolation

Le support utilise l’interpolation dans des chaînes :

```hcl
tags = {
  Name = "${var.namespace}-EC2-PUBLIC"
}
```

Cette forme permet de construire dynamiquement des noms à partir de variables ou attributs.

---

## 8. Collections vues dans le cours

### Liste

```hcl
variable "availability_zone" {
  type    = list(string)
  default = ["eu-west-3a"]
}
```

Accès par index :

```hcl
var.availability_zone[0]
```

### Map

```hcl
locals {
  labels = {
    App  = "datascientest-wordpress"
    Tier = "frontend"
  }
}
```

---

## 9. Expressions conditionnelles

Le support utilise la syntaxe ternaire :

```hcl
count = var.environment == "dev" ? 1 : 3
```

Forme générale :

```text
CONDITION ? VALEUR_SI_VRAI : VALEUR_SI_FAUX
```

---

## 10. Fonctions vues dans le cours

### `file()`

```hcl
user_data = file("install_apache.sh")
```

### `length()`

```hcl
count = length(aws_instance.datascientest_instance)
```

Le support utilise `length()` pour déterminer dynamiquement la taille d’une collection.

---

## 11. Heredoc

Le support utilise une chaîne multi-ligne pour `user_data` :

```hcl
user_data = <<EOF
#!/bin/bash
sudo yum update
sudo yum install -y httpd
EOF
```

---

## 12. Fichiers Terraform

Le cours répartit couramment une configuration en plusieurs fichiers :

```text
main.tf
provider.tf
variables.tf
outputs.tf
security.tf
ebs.tf
```

Terraform traite les fichiers `.tf` d’un même répertoire comme appartenant au même module.

---

## 13. Mise en forme et validation

```bash
terraform fmt
terraform validate
```

- `terraform fmt` : met en forme le code selon le style Terraform ;
- `terraform validate` : vérifie la validité de la configuration.

---

## 14. Mémo

```text
argument      → clé = valeur
block         → structure HCL
resource      → objet géré
provider      → accès à une API
variable      → entrée paramétrable
local         → valeur interne
output        → valeur exposée
data          → information lue
module        → bloc réutilisable
```

---

## Source pédagogique

Support DataScientest : **Terraform — Le langage HCL et providers**, complété par les exemples HCL réutilisés dans les chapitres Variables, Remote State et Modules.