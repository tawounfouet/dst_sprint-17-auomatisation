# 192 — Terraform Modules Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Référence issue principalement du chapitre **192.06 — Les modules**.

## 1. Pourquoi utiliser des modules ?

Le support présente les modules comme le mécanisme central pour rendre une configuration Terraform :

- réutilisable ;
- maintenable ;
- navigable ;
- cohérente entre environnements ;
- plus facile à partager entre projets et équipes.

Sans modules, une infrastructure importante peut devenir un ensemble volumineux de fichiers et de ressources difficiles à comprendre.

---

## 2. Définition

Un module Terraform est un ensemble de fichiers Terraform situés dans un même répertoire.

Même une configuration simple composée de fichiers `.tf` dans un répertoire constitue un module.

---

## 3. Terminologie du cours

### Module racine

Répertoire depuis lequel les commandes Terraform sont exécutées.

```text
project/
├── main.tf
├── variables.tf
└── outputs.tf
```

### Module enfant

Module appelé depuis une autre configuration.

```text
project/
└── modules/
    └── ec2/
```

### Module d’appel

Configuration qui contient un bloc `module` permettant d’appeler un autre module.

### `source`

Argument indiquant où trouver le module.

---

## 4. Structure minimale recommandée

Le support présente :

```text
├── LICENSE
├── README.md
├── main.tf
├── variables.tf
└── outputs.tf
```

Dans les cas pratiques :

```text
main.tf
variables.tf
outputs.tf
```

La séparation est logique :

```text
variables.tf → interface d’entrée
main.tf      → implémentation
outputs.tf   → interface de sortie
```

---

## 5. Appeler un module local

```hcl
module "networking" {
  source    = "./modules/networking"
  namespace = var.namespace
}
```

Autre module :

```hcl
module "ec2" {
  source     = "./modules/ec2"
  namespace  = var.namespace
  vpc        = module.networking.vpc
  sg_pub_id  = module.networking.sg_pub_id
  sg_priv_id = module.networking.sg_priv_id
  key_name   = "Datascientest"
}
```

---

## 6. Interface d’entrée

Dans un module enfant :

```hcl
variable "namespace" {
  type = string
}

variable "vpc" {
  type = any
}

variable "sg_pub_id" {
  type = any
}
```

Le module appelant fournit les valeurs correspondantes.

---

## 7. Interface de sortie

Exemple module Networking :

```hcl
output "vpc" {
  value = module.vpc
}

output "sg_pub_id" {
  value = aws_security_group.allow_ssh_pub.id
}

output "sg_priv_id" {
  value = aws_security_group.allow_ssh_priv.id
}
```

Ces outputs peuvent être consommés par un autre module.

---

## 8. Architecture du cas pratique DataScientest

Le cours construit deux modules :

```text
modules/
├── networking/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
└── ec2/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

Le module `networking` crée notamment :

- un VPC via un module du Registry ;
- subnets publics ;
- subnets privés ;
- NAT Gateway ;
- groupes de sécurité public et privé.

Le module `ec2` déploie :

- une instance publique ;
- une instance privée ;
- une AMI récupérée dynamiquement ;
- `user_data` pour l’installation de WordPress ;
- outputs d’IP.

---

## 9. Registry Terraform

Le cours utilise un module disponible sur le Registry :

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = "${var.namespace}-vpc"
  cidr            = "10.0.0.0/16"
  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
}
```

Le support distingue donc deux sources principales :

```text
module local    → ./modules/...
module Registry → terraform-aws-modules/vpc/aws
```

---

## 10. Initialisation des modules

Après ajout ou modification d’un module :

```bash
terraform init
```

Dans le cas pratique, cette commande télécharge notamment :

- le provider AWS ;
- le module VPC du Registry.

---

## 11. Bénéfices explicitement présentés

### Maintenabilité

Une évolution peut être centralisée dans un module plutôt que copiée dans plusieurs configurations.

### Navigation

Un module réseau regroupe les ressources réseau ; un module EC2 regroupe la logique de calcul.

### Cohérence

Les mêmes composants sont utilisés par différents environnements.

### Réduction de la dérive

L’utilisation d’une source modulaire commune limite les variantes manuelles entre environnements.

### Réutilisabilité

Les modules peuvent être réutilisés dans plusieurs projets ou stacks.

---

## 12. Projet final

Le projet final élargit cette approche à quatre modules :

```text
modules/
├── networking/
├── ec2/
├── rds/
└── ebs/
```

Le livrable attendu doit être :

- stacké ;
- lisible ;
- répétable ;
- réutilisable ;
- facile à déployer.

---

## 13. Dépendances entre modules

Architecture du cours :

```text
Root Module
    │
    ├── networking
    │      │
    │      ├── vpc output
    │      ├── sg_pub_id output
    │      └── sg_priv_id output
    │
    └── ec2
           ↑
           consomme les outputs networking
```

Les outputs constituent ainsi l’interface entre composants.

---

## 14. Checklist de conception

```text
[ ] responsabilité claire du module
[ ] variables d’entrée explicites
[ ] outputs utiles uniquement
[ ] main.tf lisible
[ ] module suffisamment générique pour être réutilisé
[ ] dépendances entre modules visibles
[ ] duplication limitée
[ ] secrets non codés en dur
```

---

## 15. Mémo

```text
root module   → point d’entrée
child module  → composant appelé
source        → origine du module
variables     → entrées
outputs       → sorties
Registry      → catalogue de modules réutilisables
```

---

## Source pédagogique

Support DataScientest : **Terraform — Les modules** et **Conclusion et Projet final**.