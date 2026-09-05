# 192 — Terraform Outputs Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps

## 1. Rôle des outputs

Les **outputs** exposent des valeurs utiles produites par une configuration Terraform. Le support les utilise pour afficher des informations importantes sans parcourir l’intégralité du state.

Exemples typiques dans le cours :

- IP publique d’une instance ;
- IP privée ;
- identifiant d’une ressource ;
- objet VPC renvoyé par un module ;
- identifiants de groupes de sécurité.

---

## 2. Syntaxe

```hcl
output "NOM" {
  value = EXPRESSION
}
```

Exemple :

```hcl
output "datascientest_instance_ip_public" {
  value = aws_instance.datascientest_instance.public_ip
}
```

---

## 3. `description`

```hcl
output "instance_ip_addr" {
  value       = aws_instance.datascientest_instance.public_ip
  description = "Adresse IP publique de l'instance."
}
```

Le support recommande une description concise expliquant la valeur exposée.

---

## 4. `sensitive`

```hcl
output "database_password" {
  value       = aws_db_instance.database.password
  description = "Valeur sensible"
  sensitive   = true
}
```

Dans le support, `sensitive = true` masque la valeur lors de l’affichage normal du plan ou de l’application.

---

## 5. `depends_on`

Le support indique que les blocs `output` peuvent également utiliser `depends_on` lorsqu’une dépendance explicite est requise.

---

## 6. Commande `terraform output`

Une fois la configuration appliquée :

```bash
terraform output
```

Cette commande permet de consulter les outputs déclarés.

---

## 7. Outputs et ressources multiples

Lorsque `count` est ajouté à une ressource, celle-ci devient une collection indexée dans les exemples du cours.

Une référence singulière comme :

```hcl
aws_instance.datascientest_instance.public_ip
```

n’est alors plus suffisante.

Le support montre qu’il faut exprimer la collection ou sélectionner une instance précise, par exemple :

```hcl
aws_instance.datascientest_instance[0].public_ip
```

La logique à retenir est :

```text
ressource unique    → TYPE.NOM.ATTRIBUT
ressource avec count → TYPE.NOM[INDEX].ATTRIBUT
```

---

## 8. Outputs dans un module enfant

Le chapitre Modules utilise les outputs pour définir l’interface de sortie d’un module.

### Module EC2

```hcl
output "public_ip" {
  value = aws_instance.ec2_public.public_ip
}

output "private_ip" {
  value = aws_instance.ec2_private.private_ip
}
```

### Module Networking

```hcl
output "vpc" {
  value = module.vpc
}

output "sg_pub_id" {
  value = aws_security_group.allow_ssh_pub.id
}

output "sg_priv_id" {
  value = aws_security_group.allow_ssh_priv.id
}
```

---

## 9. Consommer l’output d’un module

```hcl
module "ec2" {
  source     = "./modules/ec2"
  vpc        = module.networking.vpc
  sg_pub_id  = module.networking.sg_pub_id
  sg_priv_id = module.networking.sg_priv_id
}
```

Les outputs constituent ici le contrat entre les modules :

```text
module networking
      ↓ outputs
module ec2
```

---

## 10. Organisation recommandée par le cours

Le chapitre Modules utilise systématiquement :

```text
main.tf
variables.tf
outputs.tf
```

Cette structure rend l’interface du module lisible :

```text
variables.tf → entrées
main.tf      → ressources
outputs.tf   → sorties
```

---

## 11. Mémo

```text
variable = donnée qui entre dans le module
output   = donnée qui sort du module
```

---

## Source pédagogique

Supports DataScientest : **Terraform — Variables d’entrée** et **Terraform — Les modules**.