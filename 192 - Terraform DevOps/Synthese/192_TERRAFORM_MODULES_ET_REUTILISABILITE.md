# Terraform — Modules et réutilisabilité

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Type : Synthèse d’architecture et de conception

## 1. Pourquoi les modules deviennent nécessaires

Le cours explique qu’une configuration Terraform peut commencer dans un seul répertoire avec quelques fichiers `.tf`. Mais à mesure que l’infrastructure grandit, un projet monolithique devient plus difficile à :

- lire ;
- naviguer ;
- maintenir ;
- tester ;
- réutiliser ;
- partager entre équipes.

La duplication par copier-coller devient également source d’erreurs.

Les modules répondent à ce besoin en encapsulant des ensembles cohérents de ressources Terraform.

---

## 2. Définition d’un module Terraform

Le support définit un module comme :

> un ensemble de fichiers de configuration Terraform placés dans un même répertoire.

Même un projet Terraform très simple est donc déjà un module.

Exemple :

```text
project/
├── main.tf
├── variables.tf
└── outputs.tf
```

Ce répertoire est un module.

---

## 3. Module racine et module enfant

### Module racine

Le répertoire depuis lequel les commandes Terraform sont exécutées est le **root module**.

```text
project/
├── main.tf
├── variables.tf
└── outputs.tf
```

Si l’on lance :

```bash
terraform plan
```

à cet endroit, `project/` est le module racine.

### Module enfant

Lorsqu’un module est appelé par un autre module, il devient un **child module**.

Exemple :

```text
project/
├── main.tf
└── modules/
    └── networking/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

Le root module appelle `modules/networking`.

---

## 4. Appeler un module

Un module est appelé avec un bloc `module`.

```hcl
module "networking" {
  source    = "./modules/networking"
  namespace = var.namespace
}
```

L’argument `source` est indispensable.

Il peut pointer vers :

- un chemin local ;
- un module du Terraform Registry ;
- une autre source supportée par Terraform.

---

## 5. Structure recommandée dans le cours

Le support présente une structure minimale :

```text
module/
├── LICENSE
├── README.md
├── main.tf
├── variables.tf
└── outputs.tf
```

Dans les labs, les modules utilisent principalement :

```text
main.tf
variables.tf
outputs.tf
```

Ces trois fichiers définissent respectivement :

- les ressources et appels internes ;
- l’interface d’entrée ;
- l’interface de sortie.

---

## 6. Les variables comme interface d’entrée

Un module doit recevoir les informations nécessaires à son fonctionnement via des variables.

Exemple :

```hcl
variable "namespace" {
  type = string
}

variable "key_name" {
  type = string
}
```

Le root module fournit les valeurs :

```hcl
module "ec2" {
  source    = "./modules/ec2"
  namespace = var.namespace
  key_name  = "Datascientest"
}
```

La logique devient :

```text
Root Module
    ↓ inputs
Child Module
```

---

## 7. Les outputs comme interface de sortie

Un module expose les données utiles avec des outputs.

Exemple :

```hcl
output "public_ip" {
  value = aws_instance.ec2_public.public_ip
}
```

Le module appelant peut ensuite utiliser :

```hcl
module.ec2.public_ip
```

La communication entre modules suit donc le modèle :

```text
Variables
   ↓
Module
   ↓
Outputs
```

---

## 8. Cas pratique du cours : `networking` + `ec2`

Le chapitre Modules construit deux modules locaux.

### Module `networking`

Il gère notamment :

- VPC ;
- subnets publics ;
- subnets privés ;
- NAT Gateway ;
- Security Groups.

### Module `ec2`

Il déploie :

- une instance publique ;
- une instance privée ;
- `user_data` ;
- les associations réseau ;
- des outputs IP.

Vue globale :

```text
Root Module
│
├── module networking
│   ├── VPC
│   ├── subnets
│   ├── NAT
│   └── Security Groups
│
└── module ec2
    ├── EC2 public
    ├── EC2 private
    └── user_data
```

---

## 9. Dépendances entre modules

Le module `ec2` reçoit des outputs du module `networking` :

```hcl
module "ec2" {
  source     = "./modules/ec2"
  vpc        = module.networking.vpc
  sg_pub_id  = module.networking.sg_pub_id
  sg_priv_id = module.networking.sg_priv_id
}
```

Cette référence crée naturellement une dépendance :

```text
networking
   ↓ outputs
   ↓
ec2
```

Le module réseau doit donc produire les informations dont le module EC2 a besoin.

---

## 10. Utilisation du Terraform Registry

Le module `networking` du cours appelle lui-même un module externe :

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
}
```

Le **Terraform Registry** permet ainsi de réutiliser des modules publiés par la communauté et les fournisseurs.

Le cours l’utilise pour éviter de reconstruire manuellement toute la logique d’un VPC complet.

---

## 11. Pourquoi les modules améliorent la maintenabilité

Le support identifie plusieurs bénéfices.

### Réduction des duplications

Sans module :

```text
DEV  → copie du code réseau
QA   → copie du code réseau
PROD → copie du code réseau
```

Avec module :

```text
        module networking
          ↑     ↑     ↑
        DEV    QA    PROD
```

### Mise à jour centralisée

Une évolution d’un module peut être propagée aux environnements qui l’utilisent, plutôt que d’être reproduite manuellement dans plusieurs copies.

---

## 12. Cohérence entre environnements

Le cours met en avant la réduction de la dérive entre environnements.

```text
Module commun
   ├── DEV
   ├── TEST
   └── PROD
```

Les différences nécessaires sont alors idéalement portées par les variables d’entrée plutôt que par des duplications du code.

---

## 13. Navigation et séparation des responsabilités

Un module doit représenter une responsabilité suffisamment cohérente.

Exemple du cours :

```text
modules/
├── networking/
└── ec2/
```

Le projet final va plus loin :

```text
modules/
├── networking/
├── ec2/
├── rds/
└── ebs/
```

Cette segmentation rend la structure plus lisible :

```text
networking = réseau
ec2        = calcul
rds        = base de données
ebs        = stockage bloc
```

---

## 14. Architecture du projet final

Le sujet final demande explicitement une conception « stackée, lisible et facile à déployer ».

Structure attendue :

```text
├── modules
│   ├── networking
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── ec2
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── rds
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── ebs
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── variables.tf
├── main.tf
└── install_wordpress.sh
```

---

## 15. Réutilisabilité : principe central

Le cours conclut qu’un bon code Terraform doit être :

- répétable ;
- réutilisable ;
- structuré ;
- testable ;
- lisible.

Un module réutilisable doit donc éviter d’être trop lié à un cas unique lorsque cette dépendance peut être transformée en variable.

Exemple :

```hcl
variable "namespace" {
  type = string
}
```

Puis :

```hcl
name = "${var.namespace}-vpc"
```

Le même module peut alors produire :

```text
project-a-vpc
project-b-vpc
project-c-vpc
```

---

## 16. Limites à éviter

Les supports insistent implicitement sur certains défauts de conception :

- un énorme fichier unique ;
- copier-coller des mêmes ressources ;
- valeurs d’environnement codées en dur ;
- modules sans outputs exploitables ;
- couplage excessif entre responsabilités.

Le but n’est pas de transformer chaque ressource en module isolé, mais de construire des blocs cohérents et réutilisables.

---

## 17. Checklist d’un module

Un module doit idéalement répondre aux questions suivantes :

- [ ] Quelle responsabilité porte-t-il ?
- [ ] Quelles sont ses variables d’entrée ?
- [ ] Quels outputs expose-t-il ?
- [ ] Peut-il être utilisé par plusieurs environnements ?
- [ ] Évite-t-il les valeurs codées en dur inutiles ?
- [ ] Son nom et sa structure sont-ils compréhensibles ?
- [ ] Le root module peut-il le composer facilement avec d’autres modules ?

---

## 18. Modèle mental à retenir

```text
                Root Module
                     │
        ┌────────────┼────────────┐
        ↓            ↓            ↓
   networking       ec2          rds
        │            │            │
        └──── outputs / inputs ───┘
                     │
                    ebs
```

Les modules transforment une infrastructure monolithique en **composition de briques déclaratives**.

---

## 19. À retenir

1. Tout répertoire Terraform est un module.
2. Le répertoire exécuté est le **root module**.
3. Un module appelé est un **child module**.
4. `source` indique où trouver un module.
5. Les variables forment l’interface d’entrée.
6. Les outputs forment l’interface de sortie.
7. Les modules améliorent réutilisabilité, maintenabilité et cohérence.
8. Le Terraform Registry permet de consommer des modules externes.
9. Le projet final demande explicitement une architecture modulaire `networking/ec2/rds/ebs`.

---

## Source pédagogique

Synthèse fondée sur le chapitre DataScientest **« Terraform — Les modules »** et sur la structure modulaire exigée dans **« Conclusion et Projet final »**.