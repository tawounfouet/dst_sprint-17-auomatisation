# Validation — WordPress Terraform sur Microsoft Azure

## Validation statique

À exécuter avant tout accès Azure :

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
bash -n modules/vm/user_data.sh.tftpl
```

## Qualification Azure réelle

Pré-requis :

- authentification Azure valide ;
- `subscription_id` ;
- clé publique SSH valide ;
- quotas suffisants dans `francecentral` ;
- disponibilité du SKU VM et du SKU MySQL dans la région ;
- permissions pour créer Resource Group, réseau, VM, Managed Disk, MySQL Flexible Server, Key Vault et attributions RBAC.

Workflow manuel :

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## Contrôles fonctionnels

Après `apply` :

```bash
terraform output
curl -I "$(terraform output -raw wordpress_url)"
```

À vérifier :

- Resource Group créé dans `francecentral` ;
- VNet et deux subnets présents ;
- subnet DB délégué à `Microsoft.DBforMySQL/flexibleServers` ;
- MySQL accessible uniquement via le réseau privé ;
- VM dans la zone demandée ;
- Managed Disk de 10 GiB dans la même zone que la VM ;
- Managed Identity activée ;
- rôle Key Vault attribué à la VM ;
- WordPress répond en HTTP ;
- `/var/www/html/wp-content/uploads` est monté sur le disque additionnel ;
- aucune valeur secrète n'est versionnée dans Git.

## Destruction

Toujours terminer un lab par :

```bash
terraform destroy
```

Puis contrôler dans Azure qu'aucune ressource résiduelle facturable n'est restée dans le Resource Group.

## Limite actuelle

La présence du code Terraform dans le dépôt et une CI verte prouvent la validité statique, pas le déploiement réel. Le statut "qualifié Azure E2E" ne doit être attribué qu'après un `plan`, un `apply`, des tests WordPress et un `destroy` exécutés contre un abonnement Azure autorisé.
