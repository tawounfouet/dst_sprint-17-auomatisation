# 192 — Terraform Variables Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Référence issue principalement du chapitre **192.03 — Variables d’entrée**.

## 1. Rôle des variables

Les variables d’entrée rendent les configurations Terraform dynamiques et réutilisables sans modifier directement le code des ressources.

```text
Configuration Terraform
        +
Variables
        ↓
Même code adapté à plusieurs contextes
```

---

## 2. Déclaration

```hcl
variable "image_id" {
  type    = string
  default = "ami-EXAMPLE"
}
```

Le nom placé après `variable` doit être unique dans le module.

Le support cite comme mots réservés à ne pas utiliser pour nommer une variable :

```text
source
version
providers
count
for_each
lifecycle
depends_on
locals
```

---

## 3. Arguments vus dans le cours

### `default`

Définit une valeur utilisée lorsqu’aucune autre valeur n’est fournie.

```hcl
variable "type_instance" {
  type    = string
  default = "t3.micro"
}
```

### `type`

Contraint le type attendu.

Types simples vus dans le support :

```text
string
number
bool
any
```

Collections également utilisées :

```hcl
list(string)
```

### `description`

```hcl
variable "image_id" {
  type        = string
  description = "Identifiant de l'AMI à utiliser"
}
```

### `validation`

```hcl
variable "image_id" {
  type = string

  validation {
    condition     = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
    error_message = "La valeur doit commencer par ami-."
  }
}
```

### `sensitive`

```hcl
variable "password" {
  type      = string
  sensitive = true
}
```

Le support précise que `sensitive = true` masque la valeur dans certaines sorties CLI, mais que la valeur reste enregistrée dans le state.

### `nullable`

```hcl
variable "image_id" {
  type     = string
  nullable = false
}
```

Le cours utilise cette option pour empêcher une valeur `null`.

---

## 4. Référencer une variable

```hcl
var.NOM
```

Exemple :

```hcl
resource "aws_instance" "web" {
  ami           = var.image_id
  instance_type = var.type_instance
  monitoring    = var.monitoring
}
```

---

## 5. Sources de valeurs vues dans le cours

Le support montre plusieurs moyens de renseigner une variable :

1. valeur `default` ;
2. option CLI `-var` ;
3. fichier `.tfvars` ;
4. option `-var-file` ;
5. variable d’environnement `TF_VAR_*`.

---

## 6. Valeurs sur la ligne de commande

```bash
terraform apply -var="image_id=ami-EXAMPLE"
```

Exemple de liste :

```bash
terraform apply -var='image_id_list=["ami-ONE","ami-TWO"]'
```

---

## 7. `terraform.tfvars`

Exemple :

```hcl
type_instance = "t3.micro"
image_id      = "ami-EXAMPLE"
monitoring    = true
```

Le fichier permet de séparer les valeurs de la définition des variables.

---

## 8. Fichiers `.tfvars`

Le support indique que Terraform charge automatiquement :

```text
terraform.tfvars
terraform.tfvars.json
*.auto.tfvars
*.auto.tfvars.json
```

Pour un fichier explicitement choisi :

```bash
terraform apply -var-file="values.tfvars"
```

---

## 9. Variables d’environnement

Terraform recherche les variables commençant par `TF_VAR_`.

```bash
export TF_VAR_image_id=ami-EXAMPLE
terraform plan
```

Correspondance :

```text
TF_VAR_image_id
       ↓
var.image_id
```

---

## 10. Variables de collections

### Liste de zones de disponibilité

```hcl
variable "availability_zone" {
  type    = list(string)
  default = ["eu-west-3a"]
}
```

Utilisation :

```hcl
availability_zone = var.availability_zone[0]
```

### CIDR

```hcl
variable "cidr_block_vpc" {
  type    = list(string)
  default = ["172.16.0.0/16"]
}
```

---

## 11. Valeurs locales `locals`

Le chapitre HCL utilise également des valeurs locales, distinctes des variables d’entrée.

```hcl
locals {
  environment = "prod"
  project     = "datascientest"
}
```

Accès :

```hcl
local.environment
```

Différence à retenir :

```text
variable → interface d’entrée du module
local    → valeur interne calculée ou centralisée
```

---

## 12. Variables dans les modules

Un module enfant expose ses paramètres avec `variable` :

```hcl
variable "namespace" {
  type = string
}
```

Le module appelant lui transmet ensuite une valeur :

```hcl
module "ec2" {
  source    = "./modules/ec2"
  namespace = var.namespace
}
```

---

## 13. Cas pratique du cours

Le chapitre Variables construit progressivement :

```text
variables.tf
terraform.tfvars
instances.tf
security.tf
ebs.tf
outputs.tf
```

avec notamment :

```text
type_instance
image_id
monitoring
ebs_size
cidr_block_vpc
cidr_block_subnet
availability_zone
```

---

## 14. Checklist

Pour chaque variable :

```text
[ ] nom explicite
[ ] type défini
[ ] description si utile
[ ] default seulement si pertinent
[ ] validation si une contrainte métier/technique est nécessaire
[ ] sensitive pour une valeur à masquer dans la CLI
[ ] nullable adapté au besoin
```

---

## Source pédagogique

Support DataScientest : **Terraform — Variables d’entrée**, avec les exemples complémentaires du chapitre Modules.