# 192 — Terraform Dépendances Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps

## 1. Pourquoi les dépendances comptent

Une infrastructure contient des relations entre ressources. Terraform analyse les références utilisées dans les configurations afin de construire l’ordre de création ou de suppression nécessaire.

Exemple logique :

```text
VPC
 ↓
Subnet
 ↓
EC2
```

---

## 2. Dépendances implicites

Le support explique qu’une référence à un attribut d’une ressource crée généralement une dépendance implicite.

```hcl
resource "aws_subnet" "datascientest_subnet" {
  vpc_id = aws_vpc.datascientest_vpc.id
}
```

Terraform comprend que le subnet dépend du VPC.

Autre exemple :

```hcl
resource "aws_volume_attachment" "ebs_att" {
  volume_id   = aws_ebs_volume.datascientest_ebs.id
  instance_id = aws_instance.datascientest_instance.id
}
```

Ici, l’attachement dépend de l’EBS et de l’instance.

---

## 3. Dépendances explicites avec `depends_on`

Lorsque Terraform ne peut pas déduire la relation uniquement à partir des références, le support introduit :

```hcl
depends_on = [
  aws_security_group.datascientest_sg
]
```

Exemple :

```hcl
resource "aws_instance" "datascientest_instance" {
  ami           = var.image_id
  instance_type = var.type_instance

  depends_on = [
    aws_security_group.datascientest_sg
  ]
}
```

---

## 4. Recommandation du support

Le chapitre Variables précise que `depends_on` doit être utilisé uniquement lorsque nécessaire et accompagné d’un commentaire expliquant la raison de la dépendance.

La logique pédagogique est donc :

```text
1. préférer les références naturelles entre ressources
2. laisser Terraform déduire la dépendance
3. utiliser depends_on si la relation ne peut pas être déduite
```

---

## 5. Dépendances avec les modules

Le chapitre Modules fait circuler des outputs entre modules :

```hcl
module "networking" {
  source    = "./modules/networking"
  namespace = var.namespace
}

module "ec2" {
  source     = "./modules/ec2"
  vpc        = module.networking.vpc
  sg_pub_id  = module.networking.sg_pub_id
  sg_priv_id = module.networking.sg_priv_id
}
```

Les références `module.networking.*` créent une relation entre les deux modules.

---

## 6. Dépendance Helm vue dans le cours

Pour le déploiement WordPress/MySQL :

```hcl
resource "helm_release" "wordpress" {
  name      = "wordpress"
  namespace = "wordpress"

  depends_on = [
    helm_release.mysql
  ]
}
```

Le support impose ainsi le déploiement préalable de MySQL.

---

## 7. Dépendances et `count`

Lorsque plusieurs instances sont créées avec `count`, les références doivent cibler les éléments de la collection.

```hcl
resource "aws_volume_attachment" "datascientest_ebs_att" {
  count = length(aws_instance.datascientest_instance)

  volume_id   = aws_ebs_volume.datascientest_ebs[count.index].id
  instance_id = aws_instance.datascientest_instance[count.index].id
}
```

La correspondance se fait ici par `count.index`.

---

## 8. Dépendances principales dans le cas pratique AWS

```text
VPC
├── Subnet
│   └── Network Interface
│       └── EC2
│
├── Security Group
│   └── SG Attachment → EC2
│
└── EBS
    └── Volume Attachment → EC2
```

---

## 9. Erreurs conceptuelles à éviter

- Ajouter `depends_on` partout alors que les références suffisent.
- Référencer une ressource avec `count` comme si elle était unique.
- Créer une relation EBS/EC2 sans respecter la contrainte de zone de disponibilité mentionnée dans le support.
- Casser l’interface entre modules en supprimant un output consommé par un autre module.

---

## 10. Mémo

```text
Référence d’attribut → dépendance implicite

depends_on          → dépendance explicite

module.output        → relation entre modules

count.index          → corrélation entre collections
```

---

## Source pédagogique

Supports DataScientest : **Variables d’entrée**, **Données utilisateurs et sources de données**, **Remote State** et **Les modules**.