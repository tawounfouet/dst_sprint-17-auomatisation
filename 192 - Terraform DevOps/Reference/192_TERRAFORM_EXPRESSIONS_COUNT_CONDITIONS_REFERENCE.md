# 192 — Terraform Expressions, Count & Conditions Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Référence issue principalement du chapitre **192.05 — Remote State**.

## 1. Objectif

Le support introduit plusieurs mécanismes pour rendre les configurations Terraform plus dynamiques :

- `count` ;
- `count.index` ;
- `length()` ;
- expressions conditionnelles ternaires ;
- expressions appliquées aux collections.

---

## 2. `count`

`count` permet de créer plusieurs instances d’une même ressource.

```hcl
resource "aws_instance" "datascientest_instance" {
  ami           = var.image_id
  instance_type = var.type_instance
  count         = 3
}
```

Résultat conceptuel :

```text
aws_instance.datascientest_instance[0]
aws_instance.datascientest_instance[1]
aws_instance.datascientest_instance[2]
```

---

## 3. Changement de modèle mental

Le cours insiste sur un point important : dès qu’une ressource utilise `count`, elle n’est plus référencée comme un objet singulier mais comme une collection indexée.

Avant :

```hcl
aws_instance.datascientest_instance.public_ip
```

Après `count` :

```hcl
aws_instance.datascientest_instance[0].public_ip
```

Le message d’erreur présenté dans le support est de type :

```text
Missing resource instance key
```

Il signifie que Terraform attend un index explicite.

---

## 4. `count.index`

`count.index` représente l’index de l’itération courante.

```hcl
tags = {
  Name = "datascientest ${count.index}"
}
```

Avec `count = 3` :

```text
datascientest 0
datascientest 1
datascientest 2
```

---

## 5. Corréler plusieurs collections

Le support crée un volume EBS par instance EC2 :

```hcl
resource "aws_ebs_volume" "datascientest_ebs" {
  count = length(aws_instance.datascientest_instance)

  availability_zone = var.availability_zone[0]
  size              = var.ebs_size
}

resource "aws_volume_attachment" "datascientest_ebs_att" {
  count = length(aws_instance.datascientest_instance)

  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.datascientest_ebs[count.index].id
  instance_id = aws_instance.datascientest_instance[count.index].id
}
```

Logique :

```text
EC2[0] ↔ EBS[0]
EC2[1] ↔ EBS[1]
EC2[2] ↔ EBS[2]
```

---

## 6. Fonction `length()`

Le cours présente `length()` comme une fonction permettant de connaître la taille d’une collection.

```hcl
count = length(aws_instance.datascientest_instance)
```

Le support indique son usage sur :

- listes ;
- maps ;
- chaînes de caractères.

Dans le cas pratique, elle sert surtout à dimensionner dynamiquement le nombre de ressources associées.

---

## 7. Condition ternaire

Terraform n’utilise pas dans le cours un `if` impératif classique. Le support emploie une expression conditionnelle :

```text
CONDITION ? VALEUR_VRAIE : VALEUR_FAUSSE
```

Exemple :

```hcl
count = var.environment == "dev" ? 1 : 3
```

Interprétation :

```text
environment == dev
       ↓ oui          ↓ non
    count = 1       count = 3
```

---

## 8. Créer conditionnellement une ressource avec `count`

Le principe présenté est :

```text
count = 1 → créer une instance
count = 0 → ne pas créer de ressource
```

Ce mécanisme permet d’utiliser `count` comme condition simple.

Forme générique :

```hcl
count = CONDITION ? 1 : 0
```

---

## 9. Cas DEV / PROD du cours

Variable :

```hcl
variable "environment" {
  type    = string
  default = "dev"
}
```

Ressource :

```hcl
resource "aws_instance" "datascientest_instance" {
  ami           = var.image_id
  instance_type = var.type_instance
  count         = var.environment == "dev" ? 1 : 3

  tags = {
    Name = "datascientest ${count.index}"
  }
}
```

Résultat :

```text
DEV  → 1 instance
PROD → 3 instances
```

---

## 10. `count` et outputs

Une sortie doit prendre en compte la collection.

Pour un élément :

```hcl
output "first_ip" {
  value = aws_instance.datascientest_instance[0].public_ip
}
```

Le support montre surtout que la référence singulière devient invalide dès qu’un `count` est ajouté.

---

## 11. `count` et Security Groups

Le cours attache le même Security Group à toutes les interfaces réseau des instances :

```hcl
resource "aws_network_interface_sg_attachment" "sg_attachment" {
  count = length(aws_instance.datascientest_instance)

  security_group_id    = aws_security_group.datascientest_sg.id
  network_interface_id = aws_instance.datascientest_instance[count.index].primary_network_interface_id
}
```

---

## 12. Autres boucles mentionnées

Le support annonce trois familles :

```text
count    → ressources
for_each → ressources et blocs
for      → listes et maps
```

Le chapitre développe essentiellement `count` et les expressions conditionnelles ; `for_each` n’y fait pas l’objet d’un cas pratique détaillé.

---

## 13. Mémo

```text
count = N
→ N copies d’une ressource

count.index
→ index courant

length(collection)
→ taille de la collection

condition ? A : B
→ expression conditionnelle

resource.name[index].attribute
→ accès à une ressource créée avec count
```

---

## 14. Pièges directement rencontrés dans le cours

- Ajouter `count` sans mettre à jour les références existantes.
- Continuer à utiliser une ressource au singulier après sa transformation en collection.
- Oublier de dupliquer les ressources associées lorsqu’une relation 1:1 doit être conservée.
- Utiliser un index qui ne correspond pas à la collection attendue.

---

## Source pédagogique

Support DataScientest : **Terraform — Remote State**, section Expressions, boucles et conditions.