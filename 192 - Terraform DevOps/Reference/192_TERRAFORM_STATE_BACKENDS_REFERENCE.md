# 192 — Terraform State & Backends Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Référence issue principalement du chapitre **192.05 — Remote State**.

## 1. Pourquoi Terraform a besoin d’un state

Terraform doit conserver la correspondance entre :

- les objets déclarés dans les fichiers `.tf` ;
- les objets réellement provisionnés sur les systèmes distants.

Le support appelle cette information l’**état Terraform**.

Par défaut, cet état est stocké dans :

```text
terraform.tfstate
```

---

## 2. Rôle du fichier `terraform.tfstate`

Le cours présente le state comme le fichier permettant à Terraform de connaître l’état actuel des ressources qu’il gère.

Il stocke notamment les liaisons entre les objets de configuration et les ressources distantes.

Le support indique qu’il est enregistré au format JSON.

---

## 3. Commandes qui utilisent le state

Exemples mentionnés dans le cours :

```bash
terraform show
terraform output
```

Ces commandes permettent de consulter des informations connues de Terraform.

---

## 4. Backend local

Sans configuration spécifique, Terraform utilise un state local.

Le support présente également une configuration explicite :

```hcl
terraform {
  backend "local" {
    path = "/home/ubuntu/datascientest-backend/terraform.tfstate"
  }
}
```

Cas d’usage pédagogique : travail individuel ou démonstration locale.

---

## 5. Limite du state local en équipe

Si plusieurs personnes travaillent chacune avec leur propre copie locale :

```text
Développeur A → terraform.tfstate A
Développeur B → terraform.tfstate B
Développeur C → terraform.tfstate C
```

les états peuvent diverger.

Le chapitre Remote State introduit donc un backend partagé.

---

## 6. Backend distant S3

Le support utilise AWS S3 comme exemple de backend distant.

```hcl
terraform {
  backend "s3" {
    bucket = "example-terraform-state-bucket"
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
```

Les identifiants AWS en clair montrés dans le support d’origine ne sont volontairement pas reproduits dans ce dépôt.

---

## 7. Création du bucket dans le cas pratique

Le cours crée le bucket avec AWS CLI :

```bash
aws s3 mb s3://NOM-DE-BUCKET-UNIQUE --region eu-west-3
```

Le support rappelle que le nom du bucket doit être unique.

---

## 8. Migration du state

Lors du passage d’un backend local vers S3, le cours utilise :

```bash
terraform init -migrate-state
```

Workflow :

```text
State local
    ↓
Modification du backend
    ↓
terraform init -migrate-state
    ↓
State distant
```

---

## 9. Réinitialisation après changement de backend

Lorsqu’une configuration de backend évolue, il faut relancer l’initialisation Terraform.

Dans le cours :

```bash
terraform init -migrate-state
```

pour migrer l’état existant.

---

## 10. State et collaboration

Le backend distant répond à deux enjeux explicitement présentés :

- partager le state entre membres de l’équipe ;
- éviter que chacun maintienne sa propre copie indépendante.

Le support mentionne également le verrouillage du state afin d’empêcher des utilisations concurrentes incompatibles.

---

## 11. State et données sensibles

Le chapitre Variables rappelle qu’une variable marquée `sensitive` peut toujours être enregistrée dans le fichier d’état en clair.

Conséquence pédagogique majeure :

```text
sensitive = true
       ≠
secret absent du state
```

La protection du state est donc importante.

---

## 12. Backend vs Provider

Ces deux notions sont différentes :

```text
Provider
→ communique avec les API pour gérer les ressources

Backend
→ stocke l’état Terraform
```

Exemple d’une même configuration :

```text
Provider AWS
→ EC2, VPC, EBS...

Backend S3
→ terraform.tfstate
```

---

## 13. Fichier de configuration type

```hcl
terraform {
  backend "s3" {
    bucket = "example-terraform-state-bucket"
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }

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

---

## 14. Lifecycle simplifié

```text
Configuration HCL
      ↓
terraform init
      ↓
State chargé depuis le backend
      ↓
terraform plan
      ↓
Comparaison configuration / state / infrastructure
      ↓
terraform apply
      ↓
State mis à jour
```

---

## 15. Checklist

```text
[ ] backend choisi selon le contexte
[ ] chemin/key de state explicite
[ ] credentials non codés en dur dans les livrables
[ ] state partagé pour le travail d’équipe
[ ] migration effectuée avec init -migrate-state si nécessaire
[ ] attention aux valeurs sensibles contenues dans le state
```

---

## Source pédagogique

Support DataScientest : **Terraform — Remote State**, avec le rappel du chapitre **Variables d’entrée** sur les valeurs sensibles.