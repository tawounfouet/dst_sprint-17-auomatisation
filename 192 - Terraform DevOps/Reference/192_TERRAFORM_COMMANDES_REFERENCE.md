# 192 — Terraform Commandes Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Référence issue principalement du chapitre **192.02 — HCL, providers et ressources**.

## 1. Workflow principal

Le support organise le travail Terraform autour du cycle suivant :

```text
Écrire / modifier le code
        ↓
terraform init
        ↓
terraform validate
        ↓
terraform plan
        ↓
terraform apply
        ↓
Vérifier
        ↓
terraform destroy
```

---

## 2. `terraform --version`

Vérifie l’installation :

```bash
terraform --version
```

---

## 3. `terraform -help`

Affiche les commandes disponibles :

```bash
terraform -help
```

Aide sur une commande :

```bash
terraform fmt -help
```

---

## 4. `terraform init`

Prépare le répertoire de travail.

```bash
terraform init
```

Dans les cas pratiques du cours, cette commande :

- initialise le backend ;
- télécharge les providers ;
- prépare les modules distants ;
- crée ou met à jour `.terraform.lock.hcl`.

À relancer après un changement de provider, module ou backend.

---

## 5. `terraform init -upgrade`

Le chapitre Providers utilise :

```bash
terraform init -upgrade
```

pour réinitialiser le projet en recherchant des versions compatibles avec les contraintes déclarées.

---

## 6. `terraform init -migrate-state`

Le chapitre Remote State utilise :

```bash
terraform init -migrate-state
```

lors du passage d’un state local vers un backend distant S3.

---

## 7. `terraform fmt`

Met le code Terraform en forme :

```bash
terraform fmt
```

Le cours l’utilise avant la validation pour améliorer la lisibilité et respecter le format Terraform.

---

## 8. `terraform validate`

Vérifie la validité de la configuration :

```bash
terraform validate
```

Sortie attendue dans le cas pratique :

```text
Success! The configuration is valid.
```

---

## 9. `terraform plan`

Calcule et affiche les changements proposés sans les appliquer :

```bash
terraform plan
```

Exemple de synthèse présenté dans le support :

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Le plan permet de visualiser les ressources qui seront :

- ajoutées ;
- modifiées ;
- détruites.

---

## 10. Variables avec `plan` / `apply`

```bash
terraform apply -var="image_id=ami-EXAMPLE"
```

Avec fichier :

```bash
terraform apply -var-file="values.tfvars"
```

---

## 11. `terraform apply`

Applique les changements :

```bash
terraform apply
```

Terraform demande alors une confirmation dans les exemples interactifs du cours.

---

## 12. `terraform apply -auto-approve`

Applique sans demander de confirmation :

```bash
terraform apply -auto-approve
```

Le support utilise fréquemment cette forme dans les labs.

---

## 13. `terraform destroy`

Détruit les ressources gérées par la configuration :

```bash
terraform destroy
```

Dans les exercices :

```bash
terraform destroy -auto-approve
```

Le projet final insiste sur la suppression de toutes les ressources créées afin d’éviter des coûts cloud résiduels.

---

## 14. `terraform output`

Affiche les valeurs déclarées avec des blocs `output` :

```bash
terraform output
```

Exemples : IP publique, IP privée, identifiants de ressources.

---

## 15. `terraform show`

Le chapitre Remote State mentionne :

```bash
terraform show
```

pour consulter les informations connues de Terraform sur la configuration ou l’état.

---

## 16. Commandes listées par l’aide Terraform dans le support

Le support reproduit notamment les commandes suivantes :

```text
init
validate
plan
apply
destroy
console
fmt
force-unlock
get
graph
import
login
logout
output
providers
refresh
show
state
taint
untaint
version
workspace
```

Toutes ne font pas l’objet d’un cas pratique détaillé dans le cours.

---

## 17. Commandes utilisées autour de Kubernetes

Terraform est complété par les commandes suivantes dans les labs :

```bash
kubectl version
kubectl get all
kubectl get pod -n wordpress
```

Pour k3s :

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
```

Nettoyage k3s :

```bash
/usr/local/bin/k3s-uninstall.sh
```

---

## 18. Commandes Helm utilisées

Installation :

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Création de chart :

```bash
helm create mysql-chart
helm create wordpress-chart
```

Vérification :

```bash
helm ls -n wordpress
```

---

## 19. AWS CLI dans le cours

### Vérifier l’installation

```bash
aws --version
```

### Configurer l’accès

```bash
aws configure
```

### Créer une paire de clés

```bash
aws ec2 create-key-pair \
  --key-name Datascientest \
  --query "KeyMaterial" \
  --output text > Datascientest.pem
```

### Décrire les instances

```bash
aws ec2 describe-instances
```

### Créer un bucket S3

```bash
aws s3 mb s3://NOM-DE-BUCKET-UNIQUE --region eu-west-3
```

---

## 20. Workflow de vérification recommandé à partir du cours

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
terraform output
terraform destroy
```

Dans un projet réel du module, on complète ce workflow par des vérifications spécifiques aux ressources créées, par exemple `kubectl`, `helm` ou AWS CLI selon le cas pratique.

---

## 21. Tableau mémo

| Commande | Rôle dans le cours |
|---|---|
| `terraform --version` | vérifier Terraform |
| `terraform -help` | aide CLI |
| `terraform init` | initialiser le projet |
| `terraform init -upgrade` | mettre à jour selon les contraintes |
| `terraform init -migrate-state` | migrer le backend/state |
| `terraform fmt` | formater HCL |
| `terraform validate` | vérifier la configuration |
| `terraform plan` | prévisualiser les changements |
| `terraform apply` | appliquer les changements |
| `terraform output` | afficher les sorties |
| `terraform show` | afficher l’état/configuration interprétée |
| `terraform destroy` | supprimer les ressources |

---

## 22. Séquence à mémoriser

```text
INIT
  ↓
FMT / VALIDATE
  ↓
PLAN
  ↓
APPLY
  ↓
VERIFY
  ↓
DESTROY si environnement temporaire
```

---

## Source pédagogique

Supports DataScientest Terraform des chapitres **Introduction**, **HCL et providers**, **Variables**, **Remote State**, **Modules** et **Projet final**.