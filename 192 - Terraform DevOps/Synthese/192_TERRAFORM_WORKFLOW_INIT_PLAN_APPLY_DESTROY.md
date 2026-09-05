# Terraform — Workflow `init → plan → apply → destroy`

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Type : Synthèse opérationnelle

## 1. Objectif

Ce document synthétise le **workflow d’exécution Terraform** tel qu’il est introduit et pratiqué dans les supports DataScientest du Sprint 17.

Le cycle fondamental à retenir est :

```text
Écrire / modifier le code
        ↓
terraform init
        ↓
terraform fmt
        ↓
terraform validate
        ↓
terraform plan
        ↓
terraform apply
        ↓
Vérifier l’infrastructure
        ↓
terraform destroy
```

Les quatre commandes centrales mises en avant dans le cours sont `init`, `plan`, `apply` et `destroy`. `fmt` et `validate` complètent utilement ce workflow avant tout déploiement.

---

## 2. Étape 0 — Écrire la configuration

Terraform travaille à partir de fichiers de configuration, généralement en HCL avec l’extension `.tf`.

Une structure minimale peut être :

```text
project/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

Selon la taille du projet, la configuration peut être segmentée par domaine :

```text
project/
├── provider.tf
├── network.tf
├── instances.tf
├── security.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

Terraform lit l’ensemble des fichiers `.tf` d’un même répertoire comme une seule configuration du module courant.

---

## 3. `terraform init` — Initialiser le répertoire de travail

### Rôle

`terraform init` prépare le répertoire Terraform.

Dans les supports, cette commande est utilisée notamment pour :

- initialiser le backend ;
- télécharger les providers ;
- télécharger les modules externes ;
- créer ou mettre à jour le fichier de verrouillage `.terraform.lock.hcl` ;
- préparer le projet avant `plan` ou `apply`.

```bash
terraform init
```

### Quand relancer `init` ?

Le cours rappelle qu’il faut réinitialiser le projet après certaines modifications structurantes, par exemple :

- changement de provider ;
- changement de version de provider ;
- ajout ou modification de modules ;
- modification du backend.

Pour mettre à niveau les providers dans le cadre des contraintes déclarées :

```bash
terraform init -upgrade
```

Pour migrer un state lors d’un changement de backend :

```bash
terraform init -migrate-state
```

### Idée clé

```text
Configuration Terraform
        ↓
terraform init
        ↓
Providers + Backend + Modules prêts
```

---

## 4. `terraform fmt` — Normaliser le format

Le cours utilise `terraform fmt` afin de rendre le code conforme au format standard Terraform.

```bash
terraform fmt
```

Cette commande :

- harmonise l’indentation ;
- normalise la présentation du HCL ;
- améliore la lisibilité ;
- réduit les différences purement stylistiques dans Git.

Dans un workflow de validation, on peut considérer `fmt` comme une étape de qualité avant `validate`.

---

## 5. `terraform validate` — Vérifier la configuration

`terraform validate` vérifie que la configuration Terraform est syntaxiquement et structurellement valide.

```bash
terraform validate
```

Une validation réussie retourne un message équivalent à :

```text
Success! The configuration is valid.
```

### Ce que cette étape apporte

Elle permet de détecter des erreurs avant la génération d’un plan, par exemple :

- syntaxe HCL incorrecte ;
- références invalides ;
- certains problèmes de structure de configuration.

Le workflow devient alors :

```text
Code
 ↓
fmt
 ↓
validate
 ↓
plan
```

---

## 6. `terraform plan` — Prévisualiser les changements

### Rôle

`terraform plan` compare la configuration avec l’état connu de l’infrastructure et affiche les changements que Terraform prévoit d’effectuer.

```bash
terraform plan
```

Le cours montre des sorties du type :

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

ou :

```text
Plan: 6 to add, 0 to change, 0 to destroy.
```

### Symboles de changement

Terraform indique les opérations prévues, par exemple :

```text
+ create
~ update
- destroy
```

### Pourquoi `plan` est essentiel

`plan` permet de répondre à la question :

> « Qu’est-ce que Terraform va faire si j’applique cette configuration ? »

Il doit être lu avant `apply`, en particulier lorsque des ressources existantes peuvent être modifiées ou supprimées.

---

## 7. `terraform apply` — Appliquer la configuration

### Rôle

`terraform apply` exécute les changements nécessaires pour rapprocher l’infrastructure réelle de l’état déclaré.

```bash
terraform apply
```

Terraform présente le plan et demande une confirmation explicite.

Le cours utilise aussi fréquemment :

```bash
terraform apply -auto-approve
```

Cette option supprime la confirmation interactive.

### Attention

`-auto-approve` est pratique dans les labs DataScientest, mais son utilisation supprime une étape de contrôle humain. Dans le cadre du cours, il sert surtout à fluidifier les exercices.

### Résultat attendu

```text
Apply complete! Resources: X added, Y changed, Z destroyed.
```

---

## 8. Vérifier l’infrastructure après `apply`

Terraform ne remplace pas les outils de vérification propres à chaque plateforme.

Les supports utilisent par exemple :

### Kubernetes

```bash
kubectl get all
```

### Helm

```bash
helm ls -n wordpress
```

### AWS

```bash
aws ec2 describe-instances
```

L’idée est donc :

```text
terraform apply
      ↓
Terraform confirme la création
      ↓
Outil natif de la plateforme
      ↓
Vérification fonctionnelle
```

---

## 9. `terraform output` — Lire les sorties importantes

Lorsqu’un projet définit des blocs `output`, la commande suivante permet de les consulter :

```bash
terraform output
```

Exemple :

```hcl
output "instance_ip_addr" {
  value = aws_instance.example.public_ip
}
```

Cela permet d’exposer des informations utiles sans parcourir l’intégralité du state.

---

## 10. `terraform show` — Examiner l’état ou un plan

Le cours mentionne également `terraform show` parmi les commandes disponibles.

Elle permet d’afficher une représentation lisible :

- du state courant ;
- ou d’un plan enregistré.

---

## 11. `terraform destroy` — Nettoyer l’infrastructure

### Rôle

`terraform destroy` planifie puis supprime les ressources gérées par la configuration Terraform.

```bash
terraform destroy
```

Dans les exercices DataScientest :

```bash
terraform destroy -auto-approve
```

Le nettoyage est particulièrement important dans les labs cloud afin d’éviter de conserver des ressources inutiles et de générer des coûts.

Le projet final exige explicitement de supprimer les ressources **avec Terraform**.

---

## 12. Cycle complet à mémoriser

```text
┌──────────────────────────────┐
│        Code Terraform        │
└──────────────┬───────────────┘
               ↓
        terraform init
               ↓
         terraform fmt
               ↓
       terraform validate
               ↓
        terraform plan
               ↓
        Revue du plan
               ↓
        terraform apply
               ↓
     Vérifications techniques
               ↓
       terraform output
               ↓
       terraform destroy
```

---

## 13. Workflow après modification du code

Une fois le projet initialisé, toutes les modifications ne nécessitent pas systématiquement un nouvel `init`.

Un cycle courant devient :

```text
Modifier les fichiers .tf
        ↓
terraform fmt
        ↓
terraform validate
        ↓
terraform plan
        ↓
terraform apply
```

`terraform init` est surtout relancé lorsque les dépendances structurelles du projet changent : providers, modules, backend.

---

## 14. Checklist opérationnelle

Avant déploiement :

- [ ] Les fichiers `.tf` sont lisibles.
- [ ] Aucun secret n’est codé en dur.
- [ ] Les providers sont correctement déclarés.
- [ ] Les versions nécessaires sont contraintes.
- [ ] `terraform init` réussit.
- [ ] `terraform fmt` a été exécuté.
- [ ] `terraform validate` réussit.
- [ ] `terraform plan` a été lu.

Après déploiement :

- [ ] `terraform apply` termine correctement.
- [ ] Les outputs sont cohérents.
- [ ] Les ressources sont visibles sur la plateforme cible.
- [ ] L’application ou le service est fonctionnel.
- [ ] Les ressources temporaires sont supprimées avec `terraform destroy`.

---

## 15. À retenir

```text
init     = préparer
fmt      = formater
validate = vérifier
plan     = prévoir
apply    = exécuter
destroy  = supprimer
```

Le bon réflexe Terraform n’est donc pas simplement d’exécuter `apply`, mais de suivre un cycle contrôlé :

> **Initialiser → formater → valider → planifier → relire → appliquer → vérifier → nettoyer.**

---

## Source pédagogique

Synthèse réalisée à partir des chapitres Terraform du Sprint 17 DataScientest, en particulier les sections consacrées à la CLI, au déploiement Kubernetes/Helm, aux ressources AWS, au Remote State et au projet final.