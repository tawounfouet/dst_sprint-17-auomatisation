# Projet final Terraform — WordPress sur Microsoft Azure

Cette variante transpose le projet final DataScientest initialement réalisé sur AWS vers **Microsoft Azure**, en conservant les mêmes objectifs pédagogiques : Infrastructure as Code, modularité, reproductibilité, séparation réseau/applicatif/base de données, disque persistant, automatisation du bootstrap WordPress et absence de secrets codés en dur dans le dépôt.

> Cette version Azure est une adaptation complémentaire du projet pédagogique. Le sujet DataScientest fourni impose AWS ; les choix Azure ci-dessous sont donc une transposition technique, pas une exigence du support original.

## Architecture cible

```text
Internet
   |
Public IP
   |
NSG HTTP/HTTPS/SSH
   |
Azure Linux VM — WordPress
   |                  \
   |                   \ Managed Disk 10 GiB
   |                     -> wp-content/uploads
   |
VNet / subnet applicatif
   |
subnet MySQL délégué + Private DNS
   |
Azure Database for MySQL Flexible Server
   |
Key Vault — secret administrateur MySQL
```

## Composants

- Resource Group Azure
- Virtual Network
- subnet applicatif
- subnet privé délégué à Azure Database for MySQL Flexible Server
- NSG web
- Public IP
- Linux VM Ubuntu 24.04
- Managed Identity pour la VM
- Azure Key Vault avec RBAC
- Azure Database for MySQL Flexible Server
- haute disponibilité ZoneRedundant optionnelle
- Managed Disk supplémentaire de 10 GiB
- bootstrap WordPress par `custom_data`

## Modules

```text
modules/
├── networking/
├── mysql/
├── vm/
└── disk/
```

## Pré-requis

- Terraform >= 1.6
- abonnement Azure
- Azure CLI authentifiée localement ou identité fédérée dans CI
- une clé publique SSH valide

## Exécution locale

```bash
cp terraform.tfvars.example terraform.tfvars
# renseigner subscription_id et ssh_public_key

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output -raw wordpress_url
```

Nettoyage :

```bash
terraform destroy
```

## Sécurité

Aucun secret Azure ou mot de passe de base de données ne doit être commité. Le mot de passe MySQL est généré par Terraform puis stocké dans Azure Key Vault. La VM utilise une Managed Identity et le rôle `Key Vault Secrets User` pour le récupérer au bootstrap.

> Le mot de passe généré reste néanmoins présent dans le Terraform state. En environnement réel, le state doit donc être stocké dans un backend Azure sécurisé, chiffré et à accès restreint.
