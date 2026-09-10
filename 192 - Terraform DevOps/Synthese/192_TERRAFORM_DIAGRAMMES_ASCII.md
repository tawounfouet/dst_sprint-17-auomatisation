# 192 — Terraform DevOps — Diagrammes ASCII

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Objectif : fournir une représentation visuelle compacte des concepts, workflows et architectures étudiés.

---

## 1. Vue d'ensemble du parcours Terraform

```text
Infrastructure as Code
        │
        ▼
       HCL
        │
        ▼
    Providers
        │
        ▼
Resources / Data Sources
        │
        ▼
Variables / Locals / Outputs
        │
        ▼
   Dépendances
        │
        ▼
User Data / Provisioners
        │
        ▼
 State / Backends
        │
        ▼
Expressions / count
        │
        ▼
      Modules
        │
        ▼
  Architecture AWS
        │
        ▼
  Architecture Azure
        │
        ▼
   CI / Validation
        │
        ▼
Qualification réelle
```

---

## 2. Infrastructure as Code

```text
               APPROCHE MANUELLE

Utilisateur
    │
    ▼
Console Cloud
    │
    ├── clic
    ├── clic
    ├── clic
    └── configuration manuelle
    │
    ▼
Infrastructure

Problèmes possibles :
- erreurs humaines
- dérive de configuration
- faible reproductibilité
- faible traçabilité
```

```text
               APPROCHE IaC

Développeur / DevOps
        │
        ▼
Code Terraform
        │
        ▼
Git
        │
        ▼
Terraform
        │
        ▼
API Cloud
        │
        ▼
Infrastructure

Bénéfices :
- versionnement
- reproductibilité
- automatisation
- traçabilité
- standardisation
```

---

## 3. Architecture générale de Terraform

```text
              ┌────────────────────┐
              │    Utilisateur     │
              └─────────┬──────────┘
                        │
                        ▼
              ┌────────────────────┐
              │  Fichiers *.tf     │
              │       HCL          │
              └─────────┬──────────┘
                        │
                        ▼
              ┌────────────────────┐
              │  Terraform Core    │
              └──────┬───────┬─────┘
                     │       │
             State ──┘       └── Provider
                                  │
                                  ▼
                             API distante
                                  │
                                  ▼
                           Infrastructure
```

---

## 4. Terraform Core et Providers

```text
                    Terraform Core
                         │
        ┌────────────────┼─────────────────┐
        │                │                 │
        ▼                ▼                 ▼
   Provider AWS     Provider Azure    Provider Kubernetes
        │                │                 │
        ▼                ▼                 ▼
      AWS API          Azure API        K8s API
        │                │                 │
        ▼                ▼                 ▼
      EC2/VPC          VM/VNet          Deployments
      RDS/EBS          MySQL/Disk       Services
```

---

## 5. Resource vs Data Source

```text
                 TERRAFORM
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
      resource                 data
          │                     │
          │ crée / gère         │ lit / recherche
          │                     │
          ▼                     ▼
  aws_instance.web        data.aws_ami.ubuntu
          │                     │
          ▼                     ▼
   Instance EC2          AMI déjà existante
```

---

## 6. Variables, Locals et Outputs

```text
Entrées                           Sorties
  │                                 ▲
  ▼                                 │
variables.tf                        │
  │                                 │
  ▼                                 │
var.instance_type                   │
var.region                          │
var.environment                     │
  │                                 │
  └──────────┐                      │
             ▼                      │
          Terraform                 │
             │                      │
             ├──── locals ──────────┤
             │                      │
             ▼                      │
         Resources                  │
             │                      │
             └──────────────► outputs.tf
```

---

## 7. Résolution des variables

```text
                   Valeur variable
                         │
      ┌──────────────────┼──────────────────┐
      │                  │                  │
      ▼                  ▼                  ▼
   default         terraform.tfvars      TF_VAR_*
      │                  │                  │
      └──────────────────┼──────────────────┘
                         │
                         ▼
                    CLI -var / -var-file
                         │
                         ▼
                   Valeur effective
```

---

## 8. Dépendances et graphe Terraform

```text
aws_vpc.main
     │
     ▼
aws_subnet.public
     │
     ▼
aws_security_group.web
     │
     ▼
aws_instance.wordpress
     │
     ▼
aws_volume_attachment.data
```

Terraform déduit les dépendances à partir des références :

```text
resource A
    │
    │ A.id utilisé par B
    ▼
resource B
```

Dépendance explicite :

```text
Resource A
    │
    │ depends_on
    ▼
Resource B
```

---

## 9. Workflow Terraform

```text
Code HCL
   │
   ▼
terraform fmt
   │
   ▼
terraform init
   │
   ▼
terraform validate
   │
   ▼
terraform plan
   │
   ▼
Validation humaine
   │
   ▼
terraform apply
   │
   ▼
Infrastructure
   │
   ▼
Tests
   │
   ▼
terraform destroy
```

---

## 10. Plan Terraform

```text
Configuration souhaitée
        │
        ▼
Terraform State
        │
        ▼
État réel du provider
        │
        ▼
     Comparaison
        │
        ▼
┌───────────────────────────────┐
│ + CREATE                      │
│ ~ UPDATE                      │
│ - DESTROY                     │
└───────────────────────────────┘
        │
        ▼
  terraform plan
```

---

## 11. Terraform State

```text
       Configuration Terraform
                │
                ▼
        ┌───────────────┐
        │ Terraform     │
        │    State      │
        └───────┬───────┘
                │
                ▼
      Infrastructure réelle
```

Le state assure la correspondance :

```text
aws_instance.web
       │
       ▼
i-0123456789abcdef
```

---

## 12. State local vs Remote State

```text
STATE LOCAL

Developer A
    │
    ▼
terraform.tfstate

Developer B
    │
    ▼
terraform.tfstate

=> risque de divergence
```

```text
REMOTE STATE

Developer A ─┐
             │
Developer B ─┼────► Backend distant
             │          │
CI/CD ───────┘          ▼
                    State partagé
```

Exemple AWS :

```text
Terraform
    │
    ▼
Backend S3
    │
    ▼
terraform.tfstate
```

---

## 13. User Data

```text
Terraform
   │
   ▼
Création VM
   │
   ▼
user_data / custom_data
   │
   ▼
Boot de la VM
   │
   ├── installation paquets
   ├── configuration Apache
   ├── téléchargement WordPress
   └── configuration application
   │
   ▼
VM prête
```

---

## 14. Provisioners

```text
                    Terraform
                       │
        ┌──────────────┼───────────────┐
        │              │               │
        ▼              ▼               ▼
   local-exec         file         remote-exec
        │              │               │
        ▼              ▼               ▼
Machine locale     copie fichier     VM distante
```

---

## 15. count et count.index

```text
resource "aws_instance" "web" {
    count = 3
}

                count = 3
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
     index 0    index 1    index 2
        │          │          │
        ▼          ▼          ▼
      EC2-1      EC2-2      EC2-3
```

---

## 16. Expression conditionnelle

```text
             condition
                 │
       ┌─────────┴─────────┐
       │                   │
      true                false
       │                   │
       ▼                   ▼
   valeur A            valeur B
```

HCL :

```text
condition ? valeur_A : valeur_B
```

---

## 17. Architecture des modules Terraform

```text
                 Root Module
                     │
      ┌──────────────┼───────────────┐
      │              │               │
      ▼              ▼               ▼
 networking         compute        database
      │              │               │
      ▼              ▼               ▼
 VPC / VNet        EC2 / VM       RDS / MySQL
```

Interface d'un module :

```text
variables.tf
     │
     ▼
┌───────────────┐
│    MODULE     │
│   main.tf     │
└───────┬───────┘
        │
        ▼
   outputs.tf
```

---

## 18. Composition Root Module / Child Modules

```text
root/
│
├── main.tf
│    │
│    ├── module.networking
│    ├── module.compute
│    ├── module.database
│    └── module.storage
│
├── variables.tf
├── outputs.tf
│
└── modules/
     ├── networking/
     ├── compute/
     ├── database/
     └── storage/
```

---

## 19. Terraform avec Kubernetes et Helm

```text
Terraform
   │
   ├── Kubernetes Provider
   │        │
   │        ├── Deployment
   │        ├── Service
   │        └── Secret
   │
   └── Helm Provider
            │
            ▼
         Helm Chart
            │
            ▼
      Application K8s
```

---

## 20. Architecture WordPress AWS

```text
                         Internet
                            │
                            ▼
                   Internet Gateway
                            │
                            ▼
                 ┌───────────────────┐
                 │      AWS VPC      │
                 │    10.20.0.0/16   │
                 └────────┬──────────┘
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
     Public Subnet AZ-A         Public Subnet AZ-B
             │
             ▼
     EC2 WordPress
       t3.micro
             │
             ├──────────────► EBS 10 GiB
             │                 même AZ
             │
             │ MySQL 3306
             ▼
      ┌──────────────────────────────┐
      │          RDS MySQL           │
      │           Multi-AZ           │
      ├──────────────┬───────────────┤
      │ DB Subnet A  │ DB Subnet B   │
      │    AZ-A      │     AZ-B      │
      └──────────────┴───────────────┘
```

---

## 21. Sécurité du projet AWS

```text
RDS MySQL
    │
    │ génère le mot de passe
    ▼
AWS Secrets Manager
    │
    │ GetSecretValue
    ▼
IAM Role EC2
    │
    ▼
EC2 WordPress
    │
    ▼
wp-config.php
```

Flux réseau :

```text
Internet
   │
   │ 80 / 443
   ▼
Security Group WEB
   │
   ▼
EC2 WordPress
   │
   │ 3306
   ▼
Security Group DB
   │
   ▼
RDS MySQL
```

---

## 22. Persistance WordPress AWS

```text
EC2 WordPress
     │
     ▼
EBS 10 GiB
     │
     ▼
format ext4
     │
     ▼
/etc/fstab
     │
     ▼
/var/www/html/wp-content/uploads
```

---

## 23. Architecture WordPress Azure

```text
                         Internet
                            │
                            ▼
                    Azure Public IP
                            │
                            ▼
                   Network Interface
                            │
                            ▼
              ┌────────────────────────┐
              │     Azure VNet         │
              │                        │
              │   Application Subnet   │
              │          │             │
              │          ▼             │
              │    Linux VM WordPress  │
              │          │             │
              │          ├────► Managed Disk 10 GiB
              │          │
              │          │ MySQL 3306
              │          ▼
              │   DB Delegated Subnet  │
              │          │             │
              │          ▼             │
              │ Azure Database MySQL   │
              │ Flexible Server        │
              │ Zone Redundant HA      │
              └────────────────────────┘
```

---

## 24. Sécurité du projet Azure

```text
Terraform
    │
    ▼
Mot de passe MySQL généré
    │
    ▼
Azure Key Vault
    │
    │ RBAC
    ▼
Managed Identity VM
    │
    ▼
VM WordPress
    │
    ▼
wp-config.php
```

---

## 25. Mapping AWS / Azure

```text
AWS                         AZURE
────────────────────────────────────────────
VPC                    →    Virtual Network
Subnet                 →    Subnet
Security Group         →    Network Security Group
EC2                    →    Linux Virtual Machine
RDS MySQL              →    MySQL Flexible Server
EBS                    →    Managed Disk
Secrets Manager        →    Key Vault
IAM Role               →    Managed Identity + RBAC
Internet Gateway       →    Public IP / Azure networking
User Data              →    Custom Data
```

---

## 26. Pipeline CI Terraform

```text
Git Push
   │
   ▼
GitHub Actions
   │
   ├── terraform fmt -check
   │
   ├── terraform init -backend=false
   │
   ├── terraform validate
   │
   ├── bash -n bootstrap
   │
   └── contrôle anti-secrets
   │
   ▼
Validation statique
```

---

## 27. Qualification Cloud réelle

```text
Authentification Cloud
        │
        ▼
terraform init
        │
        ▼
terraform validate
        │
        ▼
terraform plan
        │
        ▼
terraform apply
        │
        ▼
Infrastructure réelle
        │
        ├── vérification réseau
        ├── vérification compute
        ├── vérification base
        ├── vérification stockage
        └── smoke test WordPress
        │
        ▼
Collecte des preuves
        │
        ▼
terraform destroy
```

---

## 28. Cycle de vie complet du projet Terraform

```text
                 ┌────────────────────┐
                 │   Besoin métier    │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │ Architecture cible │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │    Code HCL        │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │ Validation locale  │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │      CI/CD         │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │ terraform plan     │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │ terraform apply    │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │ Tests / Qualif.    │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │ Exploitation       │
                 └─────────┬──────────┘
                           │
                           ▼
                 ┌────────────────────┐
                 │ terraform destroy  │
                 └────────────────────┘
```

---

## 29. Terraform dans une chaîne DevOps

```text
Développeur
    │
    ▼
Git
    │
    ▼
CI/CD
    │
    ├───────────────┐
    │               │
    ▼               ▼
Terraform         Tests
    │
    ▼
Infrastructure
    │
    ▼
Ansible
    │
    ▼
Configuration applicative
    │
    ▼
Application
    │
    ▼
Prometheus / Grafana
```

Cette représentation constitue également la transition vers les autres thèmes du Sprint 17 puis vers le module Monitoring.

---

## 30. Résumé mental en une image

```text
                      TERRAFORM
                          │
           ┌──────────────┼──────────────┐
           │              │              │
           ▼              ▼              ▼
          HCL          Providers        State
           │              │              │
           ▼              ▼              ▼
      Configuration      APIs      Mémoire Terraform
           │              │              │
           └───────┬──────┴──────┬───────┘
                   │             │
                   ▼             ▼
                Modules      Dépendances
                   │             │
                   └──────┬──────┘
                          │
                          ▼
                  terraform plan
                          │
                          ▼
                  terraform apply
                          │
                          ▼
               Infrastructure réelle
                          │
                  ┌───────┴────────┐
                  ▼                ▼
                 AWS              Azure
```

---

## Conclusion

Ces diagrammes ASCII servent de complément aux cours, références et synthèses du module Terraform. Ils permettent de revoir rapidement les relations entre les concepts, les composants Terraform, le state, les modules, les architectures AWS et Azure, ainsi que le cycle complet allant du code jusqu'à la qualification réelle de l'infrastructure.
