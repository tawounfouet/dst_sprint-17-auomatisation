# Projet final Terraform — WordPress sur AWS

Ce dossier contient une implémentation complète et modulaire du projet final Terraform du Sprint 17 — Automatisation.

## Exigences pédagogiques couvertes

- région AWS `eu-west-3` ;
- instance EC2 `t3.micro` pour WordPress ;
- AMI récupérée dynamiquement ;
- Availability Zones récupérées dynamiquement ;
- base MySQL via `aws_db_instance` en Multi-AZ ;
- volume EBS supplémentaire de 10 Go dans la même AZ que l'EC2 ;
- accès HTTP 80 ;
- bonus HTTPS 443 via certificat auto-signé optionnel ;
- code segmenté en modules `networking`, `ec2`, `rds`, `ebs` ;
- aucun mot de passe codé en dur ;
- déploiement, validation et destruction via Terraform.

## Choix d'implémentation

Le support DataScientest demande simplement que les mots de passe ne soient pas codés en dur. Cette implémentation va plus loin : le mot de passe maître RDS est généré et géré par AWS Secrets Manager via `manage_master_user_password = true`. L'instance EC2 reçoit un rôle IAM limité à la lecture de ce secret pour configurer WordPress au démarrage.

La base RDS utilise `multi_az = true` et un DB subnet group couvrant deux sous-réseaux privés situés dans deux Availability Zones distinctes. Cela traduit la contrainte pédagogique « base déployée dans 2 Availability Zones » sous la forme d'un déploiement RDS Multi-AZ.

Le volume EBS de 10 Go est créé séparément et attaché à l'instance. Le script `user_data` attend l'apparition du second disque puis le monte sur `wp-content/uploads` afin de matérialiser l'usage de ce disque pour la persistance des médias WordPress.

## Architecture

```text
Internet
   |
   | HTTP 80 / HTTPS 443
   v
+--------------------------+
| Public subnet - AZ A     |
|                          |
| EC2 WordPress t3.micro   |
|      |                   |
|      +--> EBS 10 Go      |
+------+-------------------+
       |
       | MySQL 3306
       v
+--------------------------+
| Private DB subnets       |
| AZ A + AZ B              |
|                          |
| RDS MySQL db.t3.micro    |
| Multi-AZ                 |
+--------------------------+
```

## Arborescence

```text
wordpress-aws/
├── README.md
├── versions.tf
├── provider.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
├── .gitignore
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── user_data.sh.tftpl
│   ├── rds/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ebs/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── docs/
    ├── ARCHITECTURE.md
    └── VALIDATION.md
```

## Pré-requis

- Terraform >= 1.6 ;
- AWS CLI configurée localement ;
- un compte AWS autorisé à créer VPC, EC2, IAM, RDS, EBS et Secrets Manager ;
- aucune clé AWS dans les fichiers `.tf`.

Exemple d'authentification locale :

```bash
aws configure
aws sts get-caller-identity
```

Ou via variables d'environnement :

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."   # si nécessaire
```

## Configuration

Créer le fichier local de variables :

```bash
cp terraform.tfvars.example terraform.tfvars
```

Le fichier `terraform.tfvars` est ignoré par Git.

## Validation statique

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

## Déploiement

```bash
terraform apply
```

Une fois le déploiement terminé :

```bash
terraform output wordpress_url
```

Si `enable_https = true` :

```bash
terraform output wordpress_https_url
```

Le certificat HTTPS du mode pédagogique est auto-signé ; un navigateur affichera donc un avertissement. En production, utiliser un certificat public géré, typiquement via ACM derrière un load balancer ou un reverse proxy adapté.

## Destruction

Le projet est conçu comme un lab pédagogique et doit pouvoir être nettoyé entièrement avec Terraform :

```bash
terraform destroy
```

Ne supprimer aucune ressource manuellement dans la console AWS si elle a été créée par ce projet.

## Limites assumées

Cette implémentation reste volontairement proche du périmètre DataScientest. Elle n'ajoute pas d'ALB, Auto Scaling Group, CloudFront, WAF, ElastiCache ou observabilité avancée. Le but est de valider les fondamentaux Terraform : providers, ressources, variables, outputs, data sources, dépendances, state, modules et reproductibilité.