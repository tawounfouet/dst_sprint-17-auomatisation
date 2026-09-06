# Architecture — WordPress Terraform sur Microsoft Azure

## Objectif

Transposer le projet WordPress/AWS du Sprint 17 vers Azure en conservant les mêmes responsabilités architecturales, sans chercher une correspondance artificielle ressource pour ressource.

## Mapping AWS → Azure

| Projet AWS | Variante Azure |
|---|---|
| Région `eu-west-3` | `francecentral` |
| VPC | Virtual Network |
| Public subnet | App subnet |
| DB subnets | subnet délégué MySQL |
| Security Groups | Network Security Group |
| EC2 | Azure Linux Virtual Machine |
| EBS 10 GiB | Azure Managed Disk 10 GiB |
| RDS MySQL Multi-AZ | Azure Database for MySQL Flexible Server + ZoneRedundant HA |
| Secrets Manager | Azure Key Vault |
| IAM Role EC2 | System-Assigned Managed Identity + Azure RBAC |
| EC2 user_data | Azure VM custom_data |

## Flux réseau

```text
Internet
  |
  | TCP/80 (+443 optionnel)
  v
Public IP
  |
NSG Web
  |
App Subnet
  |
Linux VM / Apache / PHP / WordPress
  |
  | TCP/3306 via réseau privé
  v
Delegated MySQL Subnet
  |
MySQL Flexible Server
  |
Private DNS Zone
```

La base n'est pas exposée publiquement : elle utilise l'intégration VNet de MySQL Flexible Server et une zone DNS privée.

## Gestion du secret MySQL

Terraform génère le mot de passe administrateur, le transmet à MySQL Flexible Server et l'écrit dans Azure Key Vault. La VM possède une Managed Identity système à laquelle Terraform attribue `Key Vault Secrets User` sur le coffre. Le bootstrap récupère ensuite le secret via Azure Instance Metadata Service et l'API REST Key Vault.

```text
VM Managed Identity
      |
      | OAuth token via IMDS
      v
Azure Key Vault
      |
      v
mysql-admin-password
      |
      v
wp-config.php
```

Aucun mot de passe n'est stocké dans Git. Le Terraform state reste sensible et doit être protégé.

## Persistance des uploads

Un Managed Disk de 10 GiB est créé dans la même Availability Zone que la VM, attaché au LUN 0, détecté par le script de bootstrap, formaté en ext4 puis monté sur :

```text
/var/www/html/wp-content/uploads
```

## Haute disponibilité MySQL

Par défaut, la variante active :

```text
Zone principale : 1
Zone standby    : 2
Mode            : ZoneRedundant
```

Cette option peut être désactivée pour un lab à coût réduit via `mysql_enable_ha = false`. La disponibilité exacte des zones et du SKU doit être vérifiée dans l'abonnement/région cible au moment du `terraform plan`.
