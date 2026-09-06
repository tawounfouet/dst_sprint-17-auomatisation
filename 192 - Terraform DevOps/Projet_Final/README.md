# Projet final Terraform — Index

Ce répertoire regroupe les livrables du projet final Terraform du Sprint 17 ainsi que deux implémentations cloud : la version AWS correspondant au sujet DataScientest et une transposition complémentaire Microsoft Azure.

## Documentation du sujet AWS

- `192.07_SPECIFICATIONS_PROJET_FINAL.md` — exigences du sujet ;
- `192.07_ARCHITECTURE_WORDPRESS_AWS.md` — architecture cible ;
- `192.07_CORRIGE_PROJET_FINAL.md` — corrigé et mode d'emploi ;
- `192.07_CHECKLIST_VALIDATION.md` — checklist de validation ;
- `192.07_TESTS_ET_VALIDATION.md` — stratégie de tests ;
- `192.07_RETOUR_EXPERIENCE.md` — retour d'implémentation ;
- `192.07_QUALIFICATION_AWS_REELLE.md` — procédure de qualification AWS ;
- `AWS_GITHUB_AUTH_SETUP.md` — authentification GitHub Actions vers AWS.

## Implémentations exécutables

```text
Projet_Final/
├── wordpress-aws/      # version conforme au sujet DataScientest
└── wordpress-azure/    # transposition Microsoft Azure
```

### AWS

Modules :

```text
networking
rds
ec2
ebs
```

Principaux services : VPC, EC2, RDS MySQL Multi-AZ, EBS, Secrets Manager et IAM.

### Microsoft Azure

Modules :

```text
networking
mysql
vm
disk
```

Principaux services : Resource Group, Virtual Network, Linux VM, Azure Database for MySQL Flexible Server, Managed Disk, Key Vault et Managed Identity.

La version Azure conserve les intentions du projet — WordPress, réseau séparé, base managée, disque persistant de 10 GiB, modularité Terraform et gestion sécurisée des secrets — sans prétendre faire partie du sujet DataScientest original, qui cible AWS.

## Validation CI

Les deux implémentations disposent d'une validation statique Terraform avec :

- `terraform fmt -check -diff -recursive` ;
- `terraform init -backend=false` ;
- `terraform validate` ;
- validation Bash du bootstrap ;
- contrôles simples contre la publication accidentelle de credentials.

## Qualification réelle

La validation statique ne vaut pas qualification cloud end-to-end. Chaque version doit être qualifiée séparément sur un compte ou abonnement autorisé avec :

```text
plan
  ↓
apply
  ↓
contrôles des ressources
  ↓
smoke test WordPress
  ↓
destroy
```

La variante AWS dispose déjà de workflows dédiés de qualification. La variante Azure peut suivre le même modèle lorsqu'une identité Azure CI autorisée est disponible.
