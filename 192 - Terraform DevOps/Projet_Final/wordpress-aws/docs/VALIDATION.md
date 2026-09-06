# Validation — Projet final Terraform WordPress AWS

## 1. Validation statique

Depuis le répertoire `wordpress-aws` :

```bash
terraform fmt -recursive
terraform init
terraform validate
```

Résultat attendu :

```text
Success! The configuration is valid.
```

## 2. Inspection du plan

```bash
terraform plan -out=tfplan
terraform show tfplan
```

Le plan doit contenir au minimum les familles de ressources suivantes :

- VPC ;
- Internet Gateway ;
- 2 subnets publics ;
- 2 subnets privés DB ;
- route table publique ;
- Security Groups web et DB ;
- DB subnet group ;
- RDS MySQL `db.t3.micro` en Multi-AZ ;
- rôle IAM et instance profile pour EC2 ;
- EC2 WordPress `t3.micro` ;
- EBS `gp3` 10 GiB ;
- attachement EBS.

## 3. Contrôles avant `apply`

Vérifier que :

```text
region                  = eu-west-3
instance_type           = t3.micro
db_instance_class       = db.t3.micro
extra_ebs_size          = 10
public_subnet_cidrs      = 2 valeurs
private_db_subnet_cidrs  = 2 valeurs
```

Aucune valeur de secret AWS ou mot de passe ne doit apparaître dans le dépôt.

## 4. Déploiement

```bash
terraform apply
```

Puis :

```bash
terraform output
```

Contrôles attendus :

```bash
terraform output wordpress_url
terraform output wordpress_public_ip
terraform output rds_endpoint
terraform output extra_ebs_volume_id
```

## 5. Tests fonctionnels

### HTTP

```bash
curl -I "$(terraform output -raw wordpress_url)"
```

Résultat attendu : une réponse HTTP fournie par Apache/WordPress.

### HTTPS bonus

Si `enable_https = true` :

```bash
curl -k -I "$(terraform output -raw wordpress_https_url)"
```

L'option `-k` est nécessaire car le certificat du lab est auto-signé.

### WordPress

Ouvrir l'URL retournée par Terraform. L'écran d'installation WordPress doit apparaître si le bootstrap est terminé et la connectivité RDS opérationnelle.

## 6. Contrôles AWS

### EC2

- instance de type `t3.micro` ;
- AMI Ubuntu récupérée dynamiquement ;
- IP publique présente ;
- rôle IAM associé ;
- Security Group web correct.

### EBS

- taille : 10 GiB ;
- type : gp3 ;
- chiffrement activé ;
- même AZ que l'EC2 ;
- statut : attached.

Sur l'instance, vérifier si nécessaire :

```bash
lsblk
findmnt /var/www/html/wp-content/uploads
```

### RDS

- moteur MySQL ;
- classe `db.t3.micro` ;
- `Publicly accessible = No` ;
- Multi-AZ activé ;
- DB subnet group couvrant deux AZ ;
- Security Group autorisant 3306 uniquement depuis le SG web.

### Secrets Manager

Le secret maître doit être géré par RDS. Le mot de passe ne doit pas exister dans les fichiers Terraform versionnés.

## 7. Bootstrap EC2

Le journal du bootstrap est :

```bash
sudo tail -n 200 /var/log/wordpress-bootstrap.log
```

Contrôler :

- installation Apache/PHP ;
- récupération du secret RDS ;
- téléchargement WordPress ;
- génération de `wp-config.php` ;
- détection et montage du disque EBS ;
- configuration TLS si demandée.

## 8. Destruction

Le nettoyage fait partie de la validation :

```bash
terraform destroy
```

Après destruction, vérifier qu'aucune ressource du projet ne subsiste.

## 9. Critères de réussite

Le projet est considéré validé lorsque :

- `terraform validate` réussit ;
- le plan correspond à l'architecture attendue ;
- `terraform apply` termine sans erreur ;
- WordPress répond en HTTP ;
- la base RDS n'est pas publique ;
- le disque EBS de 10 GiB est attaché dans la même AZ ;
- aucun secret n'est commité ;
- `terraform destroy` supprime correctement l'infrastructure.

## 10. Note sur la qualification

La validation CI du dépôt couvre la syntaxe et la structure Terraform sans exécuter de ressources AWS. Une qualification end-to-end nécessite des identifiants AWS autorisés et entraîne potentiellement des coûts, notamment pour RDS Multi-AZ.