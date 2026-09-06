# Architecture — Projet final WordPress AWS

## 1. Mapping besoin → implémentation

| Besoin DataScientest | Implémentation |
|---|---|
| Région Paris | `region = "eu-west-3"` |
| EC2 `t3.micro` | module `ec2` |
| AMI dynamique | `data "aws_ami" "ubuntu"` |
| Availability Zones dynamiques | `data "aws_availability_zones" "available"` |
| Base via `aws_db_instance` | module `rds` |
| Deux AZ pour la base | DB subnet group sur deux AZ + `multi_az = true` |
| EBS 10 Go | module `ebs` |
| EC2 et EBS dans la même AZ | AZ de l'EC2 injectée dans le module EBS |
| HTTP 80 | Security Group web |
| HTTPS 443 bonus | option `enable_https`, certificat auto-signé |
| Modules | `networking`, `ec2`, `rds`, `ebs` |
| Aucun secret en dur | mot de passe RDS géré par AWS Secrets Manager |

## 2. Flux réseau

```text
                         Internet
                            |
                    +-------+-------+
                    | Internet GW   |
                    +-------+-------+
                            |
                  Public route table
                            |
                    +-------v-------+
                    | Public subnet |
                    |     AZ A      |
                    |               |
HTTP/HTTPS -------->| EC2 WordPress |
                    +-------+-------+
                            |
                            | TCP/3306
                            v
              +-------------+-------------+
              |                           |
      +-------+--------+          +-------+--------+
      | Private DB     |          | Private DB     |
      | subnet AZ A    |          | subnet AZ B    |
      +----------------+          +----------------+
              \                           /
               \                         /
                +----------+------------+
                           |
                           v
                    RDS MySQL Multi-AZ
```

## 3. Security Groups

### Web Security Group

Entrées :

- TCP/80 depuis `0.0.0.0/0` ;
- TCP/443 depuis `0.0.0.0/0` uniquement lorsque `enable_https=true` ;
- TCP/22 uniquement si `ssh_cidr` est fourni.

Le projet n'ouvre donc pas SSH par défaut.

### DB Security Group

Entrée unique :

```text
TCP/3306
source = Security Group WordPress
```

La base n'est pas publiquement accessible.

## 4. Secrets

Le sujet interdit les mots de passe codés en dur. L'implémentation utilise :

```hcl
manage_master_user_password = true
```

RDS génère le mot de passe et le stocke dans AWS Secrets Manager. Le module EC2 crée un rôle IAM ayant uniquement :

```text
secretsmanager:GetSecretValue
```

sur le secret RDS concerné.

Le bootstrap WordPress récupère ce secret au démarrage pour créer `wp-config.php`.

## 5. Persistance EBS

Le sujet impose un volume EBS additionnel de 10 GiB et la même Availability Zone que l'EC2.

Le module root passe :

```text
module.ec2.availability_zone
        ↓
module.ebs.availability_zone
```

Le volume est ensuite attaché à l'instance. Le bootstrap attend le second disque, le formate en ext4 s'il est vierge, puis le monte sur :

```text
/var/www/html/wp-content/uploads
```

La persistance additionnelle concerne ainsi concrètement les médias WordPress.

## 6. Dépendances Terraform

Les dépendances principales sont obtenues naturellement par les références entre outputs et inputs :

```text
networking
   ├──────────────> rds
   |                 |
   |                 v
   +---------------> ec2
                       |
                       v
                      ebs
```

- RDS dépend des subnets et du Security Group DB ;
- EC2 dépend du subnet, du Security Group web, de l'endpoint RDS et du secret RDS ;
- EBS dépend de l'ID et de l'AZ de l'EC2.

Aucun `depends_on` global n'est nécessaire. Un `depends_on` local est conservé dans le module EC2 pour garantir que la policy IAM de lecture du secret est attachée avant le démarrage de l'instance.

## 7. HTTPS bonus

Le support ne prescrit pas de solution TLS particulière. Pour garder le projet autonome et pédagogique, `enable_https=true` génère un certificat auto-signé Apache.

Cette solution valide le principe TLS/443 mais n'est pas une architecture de production. Une cible réelle utiliserait typiquement ACM avec un composant d'entrée compatible, par exemple un Application Load Balancer.

## 8. Périmètre volontairement non ajouté

Afin de rester centré sur les compétences du Sprint 17, le projet ne rajoute pas :

- Auto Scaling Group ;
- Application Load Balancer ;
- CloudFront ;
- WAF ;
- Route 53 ;
- ElastiCache ;
- monitoring Prometheus/Grafana ;
- pipeline de déploiement applicatif.

Ces briques relèvent d'une extension possible et non du besoin minimal du projet final Terraform.