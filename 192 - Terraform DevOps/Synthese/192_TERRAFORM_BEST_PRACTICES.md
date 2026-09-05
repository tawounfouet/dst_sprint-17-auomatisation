# Terraform — Bonnes pratiques

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Type : Synthèse des bonnes pratiques vues dans les supports

## 1. Périmètre

Ce document regroupe les **bonnes pratiques explicitement abordées ou directement déduites des exercices DataScientest** du module Terraform. Il ne cherche pas à remplacer une documentation officielle exhaustive de production.

---

## 2. Versionner l’infrastructure comme du code

L’un des bénéfices majeurs de Terraform présenté dans le cours est la gestion de l’infrastructure via des fichiers versionnables.

À conserver dans Git :

```text
*.tf
modules/
README.md
.terraform.lock.hcl
```

Le cours recommande explicitement de versionner `.terraform.lock.hcl` afin de conserver les sélections de providers effectuées par `terraform init`.

---

## 3. Contraindre les versions des providers

Le support déconseille la déclaration de version directement dans le bloc provider, méthode dépréciée.

À éviter :

```hcl
provider "kubernetes" {
  version = "~> 2.9.0"
}
```

À privilégier :

```hcl
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.9.0"
    }
  }
}
```

Cette approche améliore la reproductibilité du projet.

---

## 4. Exécuter un workflow de validation avant `apply`

Le cours utilise plusieurs commandes complémentaires :

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

Le workflow recommandé dans le cadre du module est donc :

```text
Code
 ↓
fmt
 ↓
validate
 ↓
plan
 ↓
review
 ↓
apply
```

Il est important de lire le plan avant l’application des changements.

---

## 5. Ne pas coder les secrets en dur

Le sujet final précise :

> Aucun mot de passe ne doit apparaître en dur dans le code.

Le support montre plusieurs exemples codés en dur pour simplifier certains labs, mais indique lui-même que ce n’est pas une pratique recommandée.

Pour les credentials AWS, le chapitre Modules utilise :

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

L’idée centrale est de séparer :

```text
Code versionné
     ≠
Secrets d’accès
```

---

## 6. Utiliser `sensitive` avec discernement

Terraform permet :

```hcl
variable "password" {
  type      = string
  sensitive = true
}
```

Cela masque la valeur dans certaines sorties de `plan` et `apply`.

Mais le cours rappelle que la valeur peut toujours être stockée dans le state.

Donc :

```text
sensitive = true
       ↓
Masquage CLI
       ≠
Suppression du secret dans le state
```

---

## 7. Typer les variables

Le chapitre Variables recommande l’utilisation de contraintes de type.

Exemple :

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
```

Pour une liste :

```hcl
variable "availability_zones" {
  type = list(string)
}
```

Le typage réduit les erreurs de configuration et rend l’interface d’un module plus explicite.

---

## 8. Documenter les variables

Le support présente `description` :

```hcl
variable "image_id" {
  type        = string
  description = "Identifiant de l’AMI à utiliser"
}
```

Une variable fait partie de l’interface utilisateur du module. Sa description doit donc expliquer son rôle de manière concise.

---

## 9. Valider les entrées lorsque nécessaire

Terraform permet des validations personnalisées :

```hcl
variable "image_id" {
  type = string

  validation {
    condition     = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
    error_message = "L'identifiant doit commencer par ami-."
  }
}
```

Cette validation permet de détecter une entrée incorrecte avant le déploiement.

---

## 10. Éviter les valeurs codées en dur lorsqu’elles peuvent être dynamiques

Le cours remplace une AMI fixe par une Data Source :

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}
```

Puis :

```hcl
ami = data.aws_ami.amazon_linux.id
```

Cette logique améliore la portabilité du code entre contextes compatibles.

---

## 11. Utiliser des `.tfvars` pour séparer les valeurs du code

Exemple du cours :

```text
variables.tf
terraform.tfvars
```

`variables.tf` décrit l’interface :

```hcl
variable "monitoring" {
  type    = bool
  default = false
}
```

`terraform.tfvars` fournit les valeurs :

```hcl
monitoring = true
```

Cette séparation rend le code plus réutilisable.

---

## 12. Utiliser `TF_VAR_*` dans les automatisations

Le cours présente aussi les variables d’environnement Terraform :

```bash
export TF_VAR_image_id="ami-..."
```

Elles sont utiles lorsque Terraform est exécuté dans un processus automatisé ou lorsqu’une même valeur doit être réutilisée entre plusieurs commandes.

---

## 13. Préférer les dépendances implicites

Terraform déduit automatiquement les dépendances à partir des références.

Exemple :

```hcl
subnet_id = aws_subnet.main.id
```

Le cours recommande d’utiliser `depends_on` uniquement lorsque Terraform ne peut pas détecter correctement une dépendance.

Lorsqu’il est nécessaire :

```hcl
depends_on = [
  aws_security_group.web
]
```

Le support conseille également de commenter son usage pour expliquer pourquoi cette dépendance explicite est nécessaire.

---

## 14. Utiliser `locals` sans masquer la compréhension

Les `locals` permettent de centraliser des valeurs répétitives :

```hcl
locals {
  environment = "prod"
  project     = "example"
}
```

Le cours rappelle toutefois qu’un excès de `locals` peut rendre le code moins lisible, car la valeur réelle devient plus difficile à retrouver.

La bonne pratique est donc :

> Utiliser les `locals` pour réduire la répétition, pas pour rendre toute valeur indirecte.

---

## 15. Limiter l’usage des provisioners

Les supports présentent les provisioners comme des mécanismes permettant d’exécuter des actions locales ou distantes.

Ils sont utiles pour certains cas de bootstrap ou d’intégration avec des outils de configuration.

Mais leur comportement dépend du cycle de création/destruction de la ressource et peut rendre les déploiements plus fragiles.

Dans le cours, `user_data` est privilégié pour le bootstrap initial d’EC2 lorsqu’il répond au besoin.

---

## 16. Utiliser `file()` pour externaliser les scripts

Au lieu d’écrire un long script inline :

```hcl
user_data = <<EOF
...
EOF
```

le cours propose :

```hcl
user_data = file("install_apache.sh")
```

Cela améliore :

- la lisibilité du HCL ;
- la maintenance du script ;
- la séparation des responsabilités.

---

## 17. Centraliser le state pour le travail en équipe

Pour un projet collaboratif, le chapitre Remote State privilégie un backend distant plutôt qu’un fichier local par développeur.

```hcl
terraform {
  backend "s3" {
    bucket = "..."
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
```

Le but est de partager une même source d’état et d’éviter les divergences locales.

---

## 18. Migrer proprement un backend

Lors d’un passage du state local au backend S3 :

```bash
terraform init -migrate-state
```

Le changement de backend ne doit pas être traité comme une simple modification de chemin de fichier.

---

## 19. Modulariser les configurations qui grossissent

Le cours met fortement en avant les modules comme moyen de réduire :

- duplication ;
- dérive d’environnement ;
- difficulté de navigation ;
- coût de maintenance.

Structure minimale :

```text
module/
├── main.tf
├── variables.tf
└── outputs.tf
```

Le projet final impose :

```text
modules/
├── networking/
├── ec2/
├── rds/
└── ebs/
```

---

## 20. Exposer uniquement les outputs utiles

Au lieu de forcer l’utilisateur à inspecter l’ensemble du state, un module doit exposer les valeurs utiles :

```hcl
output "public_ip" {
  value = aws_instance.web.public_ip
}
```

Les outputs sont l’interface publique du module vers le module appelant ou l’utilisateur.

---

## 21. Utiliser `count` en comprenant le changement de cardinalité

Le cours insiste sur un point important :

```hcl
count = 3
```

transforme une ressource singulière en collection.

Avant :

```hcl
aws_instance.web.id
```

Après :

```hcl
aws_instance.web[0].id
```

Toute référence associée doit donc être adaptée.

---

## 22. Détruire les ressources avec Terraform

Le projet final demande explicitement :

```bash
terraform destroy --auto-approve
```

L’idée est de conserver Terraform comme outil de gestion du cycle de vie des ressources qu’il a créées.

Supprimer manuellement une ressource gérée par Terraform peut créer un écart entre la réalité et le state jusqu’au prochain rafraîchissement/plan.

---

## 23. Taguer les ressources

Le sujet final demande de taguer les ressources afin de pouvoir les retrouver facilement dans la console AWS.

Exemple :

```hcl
tags = {
  Name = "datascientest-web"
}
```

Les tags facilitent l’identification des ressources dans un compte partagé.

---

## 24. Checklist générale

### Code

- [ ] HCL lisible et formaté.
- [ ] Variables typées.
- [ ] Variables documentées.
- [ ] Valeurs dynamiques lorsque pertinent.
- [ ] Pas de secrets en dur.
- [ ] Providers versionnés.
- [ ] `.terraform.lock.hcl` versionné.

### Architecture

- [ ] Dépendances implicites privilégiées.
- [ ] `depends_on` justifié.
- [ ] Modules cohérents.
- [ ] Outputs utiles.
- [ ] Ressources taguées.

### Exécution

- [ ] `terraform init` OK.
- [ ] `terraform fmt` exécuté.
- [ ] `terraform validate` OK.
- [ ] `terraform plan` relu.
- [ ] `terraform apply` vérifié.
- [ ] `terraform destroy` exécuté pour les labs temporaires.

### Collaboration

- [ ] Backend partagé.
- [ ] State non traité comme un fichier source ordinaire.
- [ ] Credentials externalisés.

---

## 25. À retenir

Les bonnes pratiques du cours convergent vers quatre objectifs :

```text
REPRODUCTIBILITÉ
MAINTENABILITÉ
SÉCURITÉ
COLLABORATION
```

Un bon projet Terraform doit donc être :

> **lisible, paramétrable, versionné, modulaire, testable et reproductible.**

---

## Source pédagogique

Synthèse basée sur les sept chapitres Terraform DataScientest du Sprint 17. Les recommandations ci-dessus reprennent les pratiques explicitement présentées dans les supports ou nécessaires pour satisfaire les conditions du projet final.