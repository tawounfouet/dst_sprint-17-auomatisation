# Terraform — State et collaboration

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Type : Synthèse conceptuelle et collaborative

## 1. Pourquoi le state est central

Terraform ne se contente pas de lire des fichiers `.tf`. Il maintient également une représentation de l’infrastructure qu’il gère : le **state**.

Par défaut, ce state est stocké dans :

```text
terraform.tfstate
```

Le cours explique que ce fichier contient les liaisons entre les objets déclarés dans la configuration et les objets réellement créés dans les systèmes distants.

```text
Configuration Terraform
          │
          ↓
        State
          │
          ↓
Infrastructure réelle
```

Le state permet à Terraform de savoir quelles ressources il suit et quels attributs leur sont associés.

---

## 2. State Terraform vs fichier de state

Le support distingue :

- **l’état Terraform** : les informations de correspondance entre objets Terraform et ressources distantes ;
- **le fichier d’état Terraform** : le fichier concret dans lequel ces informations sont stockées.

Par défaut :

```text
terraform.tfstate
```

Le state est représenté au format JSON.

Les commandes comme :

```bash
terraform show
terraform output
```

s’appuient sur les informations connues de Terraform.

---

## 3. Limite du state local

Pour un projet individuel, le backend local peut suffire :

```text
Développeur
    │
    ├── main.tf
    └── terraform.tfstate
```

Mais dès que plusieurs personnes travaillent sur la même infrastructure, chacun ne doit pas conserver une copie indépendante de l’état.

Sinon :

```text
Dev A → state A
Dev B → state B
Dev C → state C
```

Les équipes peuvent alors avoir des visions incohérentes de l’infrastructure.

Le besoin devient donc :

```text
                State partagé
                    ↑
          ┌─────────┼─────────┐
          │         │         │
        Dev A     Dev B     Dev C
```

---

## 4. Les backends

Le **backend** définit où Terraform stocke son state.

Le cours étudie deux cas :

1. backend local ;
2. backend distant S3.

---

## 5. Backend local explicite

Sans configuration particulière, Terraform utilise déjà un state local.

Le cours montre également comment définir explicitement un chemin :

```hcl
terraform {
  backend "local" {
    path = "/home/ubuntu/datascientest-backend/terraform.tfstate"
  }
}
```

Cette approche permet de choisir l’emplacement du fichier, mais elle ne résout pas le problème du travail collaboratif.

---

## 6. Backend distant S3

Pour partager le state, le cours configure un bucket AWS S3.

Création du bucket dans le lab :

```bash
aws s3 mb s3://<bucket-unique> --region eu-west-3
```

Puis configuration Terraform :

```hcl
terraform {
  backend "s3" {
    bucket = "<bucket-unique>"
    key    = "terraform.tfstate"
    region = "eu-west-3"
  }
}
```

Le principe devient :

```text
Développeur A ─┐
Développeur B ─┼──→ S3 Backend → terraform.tfstate
Développeur C ─┘
```

---

## 7. Migration du state

Lorsqu’on passe d’un backend local à un backend distant, le cours utilise :

```bash
terraform init -migrate-state
```

Cette commande réinitialise le répertoire et accompagne le déplacement de l’état vers le nouveau backend.

Workflow :

```text
State local
    ↓
Modifier backend
    ↓
terraform init -migrate-state
    ↓
State distant
```

---

## 8. Verrouillage du state

Le support insiste sur le fait que Terraform protège le state pendant les opérations afin d’éviter qu’il soit utilisé simultanément de manière incompatible.

La logique recherchée est :

```text
Utilisateur A modifie l’infrastructure
        ↓
State verrouillé pendant l’opération
        ↓
Utilisateur B ne doit pas écrire en parallèle
```

Cela réduit les risques de concurrence lors des mises à jour.

---

## 9. Pourquoi le state ne doit pas être traité comme un simple fichier source

Le cours montre qu’un state contient de nombreux attributs de ressources, y compris des valeurs potentiellement sensibles.

Par exemple, marquer une variable comme :

```hcl
sensitive = true
```

masque sa valeur dans certaines sorties CLI, mais **ne signifie pas que la valeur disparaît du state**.

Point clé :

```text
sensitive = true
       ↓
Masquage dans l’interface Terraform
       ≠
Chiffrement automatique du state
```

Le contrôle de l’accès au backend est donc essentiel.

---

## 10. Collaboration et Git

Le code Terraform et le state ne jouent pas le même rôle.

```text
Git
│
├── *.tf
├── modules/
├── README.md
└── .terraform.lock.hcl

Backend
└── terraform.tfstate
```

Le code doit être versionné et partagé. Le state d’une infrastructure collaborative est, lui, centralisé dans le backend.

Le cours indique explicitement que `.terraform.lock.hcl` doit être intégré au dépôt afin de conserver les sélections de providers.

---

## 11. Évolution collaborative d’une infrastructure

Un workflow d’équipe cohérent peut être représenté ainsi :

```text
1. Récupérer le code Git
          ↓
2. terraform init
          ↓
3. Terraform récupère le backend partagé
          ↓
4. Modifier le code
          ↓
5. terraform plan
          ↓
6. Revue
          ↓
7. terraform apply
          ↓
8. Mise à jour du state distant
```

Le point central est que chaque membre travaille à partir de la **même source de vérité d’état**.

---

## 12. Le state et les outputs

Les outputs facilitent l’exposition d’informations utiles sans demander à l’utilisateur de parcourir tout le state.

Exemple :

```hcl
output "public_ip" {
  value = aws_instance.web.public_ip
}
```

Puis :

```bash
terraform output
```

Le state contient beaucoup plus d’informations que celles qui doivent être exposées aux utilisateurs.

---

## 13. Le state et `count`

Le chapitre Remote State introduit ensuite `count`.

Lorsqu’une ressource passe de :

```hcl
resource "aws_instance" "web" {
  # ...
}
```

à :

```hcl
resource "aws_instance" "web" {
  count = 3
}
```

Terraform ne gère plus une ressource singulière, mais une collection indexée :

```text
aws_instance.web[0]
aws_instance.web[1]
aws_instance.web[2]
```

Cette évolution se reflète dans la manière dont les objets sont représentés et référencés dans l’état.

---

## 14. Source de vérité : code, state et réalité

Pour comprendre Terraform, il faut distinguer trois notions :

```text
Configuration
Ce que l’on souhaite

State
Ce que Terraform connaît et suit

Infrastructure distante
Ce qui existe réellement
```

Terraform utilise ces informations pour déterminer les changements nécessaires.

---

## 15. Problèmes typiques d’un mauvais usage du state

À partir des risques décrits dans le cours, les principaux problèmes sont :

- plusieurs fichiers state divergents dans une équipe ;
- perte du state local ;
- exposition de données sensibles ;
- modifications concurrentes ;
- changement de backend sans migration ;
- suppression manuelle de ressources sans cohérence avec la gestion Terraform.

Le projet final insiste d’ailleurs sur le fait que les ressources créées avec Terraform doivent être détruites avec Terraform.

---

## 16. Checklist de collaboration

- [ ] Le code Terraform est versionné.
- [ ] Les credentials ne sont pas présents dans le dépôt.
- [ ] `.terraform.lock.hcl` est conservé dans Git.
- [ ] Le state partagé utilise un backend distant pour le travail d’équipe.
- [ ] Tous les collaborateurs pointent vers le même backend.
- [ ] Toute migration de backend passe par une réinitialisation appropriée.
- [ ] Les valeurs sensibles ne sont pas considérées comme protégées simplement grâce à `sensitive = true`.
- [ ] Les changements sont inspectés avec `terraform plan` avant application.
- [ ] Les ressources gérées par Terraform sont modifiées/supprimées avec Terraform.

---

## 17. À retenir

```text
Code = intention
State = mémoire Terraform
Cloud = réalité distante
Backend = lieu de stockage du state
```

Pour un projet collaboratif :

> **Le code se partage via Git ; le state se centralise via un backend.**

---

## Source pédagogique

Synthèse réalisée principalement à partir du chapitre DataScientest **« Terraform — Remote State »**, complété par les sections Variables et Modules concernant `sensitive`, `.terraform.lock.hcl` et le travail avec des configurations réutilisables.