# 192 — Terraform Resources & Data Sources Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps

## 1. Deux notions à distinguer

Le cours Terraform distingue clairement :

```text
resource → Terraform crée ou gère un objet

data     → Terraform lit une information existante
```

Cette distinction est fondamentale dans un projet Terraform.

---

## 2. Ressources Terraform

Une ressource représente une composante d’infrastructure gérée par Terraform.

Forme générale :

```hcl
resource "TYPE" "NOM" {
  # arguments
}
```

Exemple AWS :

```hcl
resource "aws_instance" "datascientest_instance" {
  ami           = var.image_id
  instance_type = var.type_instance
}
```

Exemple Kubernetes :

```hcl
resource "kubernetes_service" "wordpress_service" {
  metadata {
    name = "wordpress-service"
  }
}
```

---

## 3. Adresse d’une ressource

Une ressource est généralement référencée sous la forme :

```text
TYPE.NOM.ATTRIBUT
```

Exemple :

```hcl
aws_instance.datascientest_instance.id
```

ou :

```hcl
aws_instance.datascientest_instance.public_ip
```

---

## 4. Ressources AWS vues dans le cours

### EC2

```hcl
resource "aws_instance" "web" {
  ami           = var.image_id
  instance_type = "t3.micro"
}
```

### VPC

```hcl
resource "aws_vpc" "datascientest_vpc" {
  cidr_block = "172.16.0.0/16"
}
```

### Subnet

```hcl
resource "aws_subnet" "datascientest_subnet" {
  vpc_id            = aws_vpc.datascientest_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "eu-west-3a"
}
```

### Security Group

```hcl
resource "aws_security_group" "datascientest_sg" {
  name   = "datascientest-sg"
  vpc_id = aws_vpc.datascientest_vpc.id
}
```

### Interface réseau

```hcl
resource "aws_network_interface" "interface_reseau_instance" {
  subnet_id   = aws_subnet.datascientest_subnet.id
  private_ips = ["172.16.10.100"]
}
```

### Volume EBS

```hcl
resource "aws_ebs_volume" "datascientest_ebs" {
  availability_zone = var.availability_zone[0]
  size              = var.ebs_size
}
```

### Attachement EBS

```hcl
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.datascientest_ebs.id
  instance_id = aws_instance.datascientest_instance.id
}
```

### RDS

Le projet final demande l’utilisation de la ressource :

```text
aws_db_instance
```

pour déployer la base de données du site WordPress.

---

## 5. Ressources Kubernetes vues dans le cours

Le support manipule notamment :

- `kubernetes_secret` ;
- `kubernetes_deployment` ;
- `kubernetes_service`.

Exemple :

```hcl
resource "kubernetes_secret" "mysql_password" {
  metadata {
    name = "datascientest-mysql-password"
  }

  data = {
    password = "EXEMPLE_A_NE_PAS_CODER_EN_DUR_EN_PRODUCTION"
  }
}
```

Le cours utilise ensuite ces ressources pour déployer WordPress et MySQL sur k3s.

---

## 6. Ressource Helm

Le provider Helm expose notamment :

```hcl
resource "helm_release" "wordpress" {
  name      = "wordpress"
  namespace = "wordpress"
  chart     = "${path.module}/wordpress-chart"
}
```

Le support déploie deux releases : MySQL puis WordPress, avec une dépendance entre les deux.

---

## 7. Data Sources

Une data source permet à Terraform de récupérer une information existante depuis l’API d’un provider.

Forme générale :

```hcl
data "TYPE" "NOM" {
  # filtres
}
```

Référence :

```text
data.TYPE.NOM.ATTRIBUT
```

---

## 8. Exemple principal : récupérer une AMI dynamiquement

Le cours remplace un identifiant AMI codé en dur par une data source :

```hcl
data "aws_ami" "datascientest_ami" {
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
resource "aws_instance" "datascientest_instance" {
  ami           = data.aws_ami.datascientest_ami.id
  instance_type = var.type_instance
}
```

Objectif pédagogique : rendre le code moins dépendant d’un identifiant d’AMI spécifique à une région.

---

## 9. Data source des Availability Zones

Dans le chapitre Modules :

```hcl
data "aws_availability_zones" "available" {}
```

Puis :

```hcl
azs = data.aws_availability_zones.available.names
```

Cette data source est utilisée avec le module VPC importé depuis le Registry Terraform.

---

## 10. Dépendances implicites créées par les références

Lorsque l’attribut d’une ressource est utilisé dans une autre ressource, Terraform peut déduire une dépendance.

```hcl
resource "aws_subnet" "subnet" {
  vpc_id = aws_vpc.main.id
}
```

Ici :

```text
aws_vpc.main
      ↓
aws_subnet.subnet
```

---

## 11. Resource vs Data Source

| Besoin | Construction |
|---|---|
| Créer une VM | `resource "aws_instance" ...` |
| Lire une AMI existante | `data "aws_ami" ...` |
| Créer un VPC | `resource "aws_vpc" ...` |
| Lire les AZ disponibles | `data "aws_availability_zones" ...` |
| Créer un service Kubernetes | `resource "kubernetes_service" ...` |

---

## 12. Mémo

```text
RESOURCE
Terraform possède le cycle de vie de l’objet déclaré.

DATA SOURCE
Terraform interroge une source externe pour obtenir une valeur utilisable ailleurs.
```

---

## Source pédagogique

Supports DataScientest : **Le langage HCL et providers**, **Variables d’entrée**, **Données utilisateurs et sources de données**, **Les modules** et **Projet final**.