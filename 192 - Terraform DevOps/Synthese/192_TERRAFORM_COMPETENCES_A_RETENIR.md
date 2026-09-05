# Terraform — Compétences à retenir

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Type : Synthèse des compétences

## 1. Finalité du module

Le module Terraform du Sprint 17 vise à rendre capable d’**automatiser le déploiement et la gestion d’infrastructures** avec une approche Infrastructure as Code.

Les supports couvrent progressivement :

```text
IaC
 ↓
HCL
 ↓
Providers
 ↓
Resources
 ↓
Variables / Outputs
 ↓
User Data / Provisioners / Data Sources
 ↓
State / Backends
 ↓
Expressions / Count / Conditions
 ↓
Modules
 ↓
Projet final AWS
```

---

## 2. Compétence 1 — Comprendre l’Infrastructure as Code

Il faut savoir expliquer :

- ce qu’est l’IaC ;
- pourquoi elle améliore la reproductibilité ;
- en quoi elle réduit les manipulations manuelles ;
- pourquoi elle facilite le versionnement ;
- ce que signifie une approche déclarative ;
- le principe d’idempotence.

À retenir :

```text
Infrastructure manuelle
       ↓
Infrastructure décrite par du code
       ↓
Versionnable + reproductible + automatisable
```

---

## 3. Compétence 2 — Installer et initialiser Terraform

Être capable de :

- installer Terraform sur Ubuntu/Debian ;
- vérifier la version installée ;
- initialiser un projet ;
- comprendre le rôle de `.terraform.lock.hcl` ;
- relancer `init` lorsque providers, modules ou backend changent.

Commandes clés :

```bash
terraform --version
terraform init
terraform init -upgrade
terraform init -migrate-state
```

---

## 4. Compétence 3 — Lire et écrire du HCL

Savoir reconnaître et utiliser :

- arguments ;
- blocs ;
- labels ;
- identifiants ;
- commentaires ;
- blocs imbriqués.

Exemple :

```hcl
resource "aws_instance" "web" {
  instance_type = "t3.micro"
}
```

Il faut comprendre la structure :

```text
TYPE DE BLOC
      ↓
resource
      ↓
TYPE DE RESSOURCE
      ↓
aws_instance
      ↓
NOM LOGIQUE
      ↓
web
```

---

## 5. Compétence 4 — Configurer des providers

Être capable de :

- expliquer le rôle d’un provider ;
- déclarer AWS, Kubernetes ou Helm ;
- comprendre que les providers communiquent avec des API ;
- utiliser `required_providers` ;
- contraindre les versions.

Exemple :

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

---

## 6. Compétence 5 — Maîtriser le workflow Terraform

Il faut savoir utiliser :

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
```

Et comprendre leur rôle :

```text
init      → préparer
fmt       → formater
validate  → vérifier
plan      → prévisualiser
apply     → appliquer
destroy   → supprimer
```

---

## 7. Compétence 6 — Créer des ressources

Savoir déclarer des ressources Terraform à partir d’un provider.

Exemples rencontrés dans le cours :

### AWS

```text
aws_instance
aws_vpc
aws_subnet
aws_network_interface
aws_security_group
aws_ebs_volume
aws_volume_attachment
aws_network_interface_sg_attachment
```

### Kubernetes

```text
kubernetes_secret
kubernetes_deployment
kubernetes_service
```

### Helm

```text
helm_release
```

---

## 8. Compétence 7 — Utiliser des variables d’entrée

Être capable de :

- déclarer une variable ;
- définir son type ;
- définir une valeur par défaut ;
- ajouter une description ;
- valider une valeur ;
- utiliser `sensitive` ;
- utiliser `nullable`.

Exemple :

```hcl
variable "instance_type" {
  type        = string
  description = "Type de l'instance EC2"
  default     = "t3.micro"
}
```

---

## 9. Compétence 8 — Fournir des valeurs aux variables

Savoir utiliser plusieurs mécanismes :

```text
default
-var
terraform.tfvars
*.auto.tfvars
-var-file
TF_VAR_*
```

Exemples :

```bash
terraform apply -var="instance_type=t3.micro"
terraform apply -var-file="prod.tfvars"
export TF_VAR_environment="prod"
```

---

## 10. Compétence 9 — Exploiter les outputs

Savoir exposer les données importantes d’une infrastructure :

```hcl
output "public_ip" {
  value = aws_instance.web.public_ip
}
```

Puis :

```bash
terraform output
```

Il faut comprendre que les outputs servent aussi d’interface entre modules.

---

## 11. Compétence 10 — Comprendre les dépendances

Savoir distinguer :

### Dépendance implicite

```hcl
subnet_id = aws_subnet.main.id
```

### Dépendance explicite

```hcl
depends_on = [
  aws_security_group.web
]
```

Le bon réflexe est de laisser Terraform inférer les dépendances via les références lorsque c’est possible.

---

## 12. Compétence 11 — Utiliser `user_data`

Savoir automatiser le bootstrap initial d’une instance EC2.

Exemple :

```hcl
user_data = file("install_apache.sh")
```

Il faut comprendre que les commandes sont exécutées lors du lancement initial de l’instance.

---

## 13. Compétence 12 — Comprendre les provisioners

Savoir distinguer :

```text
local-exec
file
remote-exec
```

### `local-exec`

Exécute une commande sur la machine qui lance Terraform.

### `file`

Copie un fichier vers une ressource distante.

### `remote-exec`

Exécute des commandes sur une ressource distante.

Il faut aussi comprendre :

- `self` ;
- `when = destroy` ;
- `on_failure` ;
- le besoin d’un bloc `connection` pour les actions distantes.

---

## 14. Compétence 13 — Utiliser des Data Sources

Être capable de récupérer des informations existantes depuis l’API du provider.

Exemple important du cours :

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

Le modèle mental :

```text
resource = crée / gère

data source = lit / récupère
```

---

## 15. Compétence 14 — Comprendre le state

Il faut pouvoir expliquer le rôle de :

```text
terraform.tfstate
```

et distinguer :

```text
Configuration
State
Infrastructure distante
```

Le state représente la mémoire opérationnelle de Terraform sur les objets qu’il gère.

---

## 16. Compétence 15 — Configurer un backend distant

Être capable de comprendre pourquoi un projet collaboratif utilise un backend distant.

Exemple étudié :

```hcl
terraform {
  backend "s3" {
    bucket = "..."
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
```

Et savoir migrer :

```bash
terraform init -migrate-state
```

---

## 17. Compétence 16 — Utiliser `count`

Savoir créer plusieurs instances d’une ressource :

```hcl
count = 3
```

Et comprendre que la ressource devient une collection :

```hcl
aws_instance.web[0]
aws_instance.web[1]
aws_instance.web[2]
```

Savoir utiliser :

```text
count.index
length()
[*]
```

selon les cas présentés dans le cours.

---

## 18. Compétence 17 — Utiliser des conditions

Terraform ne propose pas de `if` procédural classique dans les ressources.

Le cours utilise les expressions ternaires :

```hcl
count = var.environment == "dev" ? 1 : 3
```

Il faut savoir lire :

```text
condition ? valeur_si_vrai : valeur_si_faux
```

---

## 19. Compétence 18 — Comprendre les modules

Savoir distinguer :

```text
root module
child module
calling module
source
inputs
outputs
```

Et construire une arborescence :

```text
modules/
├── networking/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── ec2/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## 20. Compétence 19 — Consommer un module du Terraform Registry

Le cours utilise :

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
}
```

Il faut comprendre l’intérêt :

- réutilisation ;
- réduction de duplication ;
- accélération de la conception ;
- standardisation de briques d’infrastructure.

---

## 21. Compétence 20 — Piloter Kubernetes avec Terraform

Être capable de comprendre le workflow :

```text
Terraform
   ↓
Provider Kubernetes
   ↓
API Kubernetes
   ↓
Deployment / Service / Secret
```

Et savoir vérifier les résultats avec :

```bash
kubectl get all
```

---

## 22. Compétence 21 — Déployer avec Helm via Terraform

Comprendre :

- la notion de chart ;
- `values.yaml` ;
- `helm_release` ;
- la dépendance entre releases ;
- la vérification avec `helm ls`.

Exemple :

```hcl
resource "helm_release" "wordpress" {
  name      = "wordpress"
  namespace = "wordpress"
  chart     = "${path.module}/wordpress-chart"
}
```

---

## 23. Compétence 22 — Construire une architecture AWS cohérente

À partir des labs, il faut pouvoir articuler :

```text
VPC
 ↓
Subnet
 ↓
Security Group
 ↓
EC2
 ↓
EBS
```

et comprendre les contraintes comme :

- même Availability Zone pour EC2/EBS ;
- ouverture contrôlée des ports ;
- dépendances entre ressources ;
- récupération dynamique de certaines données AWS.

---

## 24. Compétence 23 — Réaliser le projet final

Le sujet final demande de construire une architecture WordPress avec :

- région `eu-west-3` ;
- une instance EC2 `t3.micro` ;
- AMI récupérée dynamiquement ;
- Availability Zones récupérées dynamiquement ;
- RDS avec `aws_db_instance` ;
- type `db.t3.micro` ;
- déploiement base de données sur deux AZ ;
- EBS de 10 Go ;
- HTTP port 80 ;
- HTTPS en bonus ;
- modules `networking`, `ec2`, `rds`, `ebs` ;
- aucun mot de passe en dur ;
- code répétable et réutilisable ;
- nettoyage avec Terraform.

---

## 25. Compétence 24 — Sécuriser le projet

Les réflexes essentiels issus du cours :

- ne pas publier les credentials ;
- externaliser les secrets ;
- comprendre les limites de `sensitive` ;
- centraliser correctement le state collaboratif ;
- contrôler les ports réseau ;
- détruire les ressources de lab après usage.

---

## 26. Compétence 25 — Produire un code maintenable

Être capable de produire un projet :

```text
lisible
modulaire
paramétrable
versionné
réutilisable
reproductible
```

Cela implique notamment :

- éviter le copier-coller ;
- utiliser les variables ;
- utiliser les modules ;
- exposer les bons outputs ;
- documenter les interfaces ;
- relire les plans avant application.

---

## 27. Carte mentale finale

```text
                     TERRAFORM
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
      HCL             STATE            PROVIDERS
       │                 │                 │
       ↓                 ↓                 ↓
   Resources          Backend        AWS / K8s / Helm
       │                                   │
       ├── Variables                       ↓
       ├── Outputs                    Infrastructure
       ├── Data Sources
       ├── Dependencies
       ├── count / conditions
       └── Modules
```

---

## 28. Niveau attendu en fin de module

À la fin du module, l’objectif n’est pas seulement de connaître quelques commandes Terraform.

Il faut être capable de passer de :

```text
Besoin d’infrastructure
```

à :

```text
Architecture
    ↓
Code HCL
    ↓
Providers / Resources
    ↓
Variables / Data Sources
    ↓
State / Backend
    ↓
Modules
    ↓
terraform plan
    ↓
terraform apply
    ↓
Infrastructure opérationnelle
```

---

## 29. Checklist de maîtrise

Je sais :

- [ ] expliquer l’IaC et Terraform ;
- [ ] écrire du HCL ;
- [ ] déclarer un provider ;
- [ ] créer des resources ;
- [ ] utiliser des variables ;
- [ ] utiliser `.tfvars` et `TF_VAR_*` ;
- [ ] créer des outputs ;
- [ ] gérer les dépendances ;
- [ ] utiliser `user_data` ;
- [ ] expliquer les provisioners ;
- [ ] utiliser des Data Sources ;
- [ ] expliquer le state ;
- [ ] configurer un backend distant ;
- [ ] utiliser `count` ;
- [ ] écrire une condition ternaire ;
- [ ] créer et appeler un module ;
- [ ] exploiter le Terraform Registry ;
- [ ] piloter AWS ;
- [ ] piloter Kubernetes ;
- [ ] déployer une release Helm ;
- [ ] utiliser `fmt`, `validate`, `plan`, `apply`, `destroy` ;
- [ ] construire une architecture Terraform modulaire ;
- [ ] éviter les secrets en dur ;
- [ ] réaliser le projet final WordPress AWS.

---

## 30. À retenir en une phrase

> **Terraform permet de décrire une infrastructure de manière déclarative, de la paramétrer, de la versionner, d’en suivre l’état et de la composer en modules réutilisables afin de la déployer de façon reproductible.**

---

## Source pédagogique

Synthèse des compétences fondée sur les sept chapitres Terraform du Sprint 17 DataScientest et sur les conditions de validation du projet final.