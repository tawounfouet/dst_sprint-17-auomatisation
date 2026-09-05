# Terraform — Anti-patterns et pièges

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Type : Synthèse des erreurs fréquentes et points de vigilance

## 1. Objectif

Ce document regroupe les principaux **pièges observables dans les supports DataScientest** et les anti-patterns que le cours cherche progressivement à corriger.

L’objectif n’est pas de dresser une liste exhaustive de tous les problèmes possibles avec Terraform, mais de formaliser les erreurs pédagogiquement importantes rencontrées dans le parcours.

---

## 2. Coder les credentials dans les fichiers Terraform

Les premiers exemples du cours montrent parfois des credentials AWS directement dans le provider pour simplifier les labs.

Exemple à ne pas reproduire dans un dépôt :

```hcl
provider "aws" {
  region     = "eu-west-3"
  access_key = "..."
  secret_key = "..."
}
```

Le chapitre Modules montre ensuite une approche externalisée via l’environnement.

Le piège est évident :

```text
Secret dans le code
      ↓
Commit Git
      ↓
Secret exposé
```

Le projet final impose explicitement l’absence de mots de passe codés en dur.

---

## 3. Croire que `sensitive = true` sécurise le state

```hcl
variable "password" {
  sensitive = true
}
```

Cette option masque la valeur dans certaines sorties CLI.

Mais le cours précise que la valeur peut rester présente dans le fichier `terraform.tfstate`.

Erreur de raisonnement :

```text
sensitive = true
      =
secret chiffré
```

En réalité :

```text
sensitive = true
      =
valeur masquée dans certaines sorties
```

---

## 4. Laisser des AMI codées en dur

Un ID d’AMI dépend de la région.

Exemple fragile :

```hcl
ami = "ami-xxxxxxxx"
```

Le cours montre qu’un changement de région peut rendre la configuration inutilisable.

Solution introduite :

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}
```

Le piège consiste donc à traiter une donnée dynamique de plateforme comme une constante universelle.

---

## 5. Utiliser `depends_on` partout

Terraform construit naturellement un graphe à partir des références.

Exemple :

```hcl
subnet_id = aws_subnet.main.id
```

Cette référence crée déjà une dépendance.

Ajouter systématiquement :

```hcl
depends_on = [aws_subnet.main]
```

est inutile dans ce cas.

Le cours recommande de réserver `depends_on` aux dépendances que Terraform ne peut pas déduire automatiquement.

---

## 6. Ne pas comprendre l’effet de `count`

C’est l’un des pièges les plus explicitement illustrés dans le support Remote State.

Avant `count` :

```hcl
aws_instance.web.public_ip
```

Après :

```hcl
resource "aws_instance" "web" {
  count = 3
}
```

La ressource devient une collection :

```hcl
aws_instance.web[0].public_ip
aws_instance.web[1].public_ip
aws_instance.web[2].public_ip
```

Le cours montre alors l’erreur :

```text
Missing resource instance key
```

Le piège est de continuer à référencer une ressource au singulier après l’avoir transformée en collection.

---

## 7. Multiplier les ressources avec `count` sans adapter les dépendances

Le cours montre que si trois EC2 sont créées, les ressources liées doivent souvent être adaptées elles aussi.

Exemple :

```text
3 EC2
↓
3 EBS
↓
3 attachments
```

Si une ressource associée reste singulière alors qu’elle doit suivre chaque instance, des références deviennent invalides ou fonctionnellement incorrectes.

---

## 8. Attacher un EBS dans une mauvaise Availability Zone

Le cours rappelle explicitement qu’un volume EBS et l’instance EC2 à laquelle il est attaché doivent se trouver dans la **même Availability Zone**.

Erreur :

```text
EC2 → eu-west-3a
EBS → eu-west-3b
```

L’attachement ne peut pas fonctionner comme attendu.

Le projet final attire de nouveau l’attention sur cette contrainte.

---

## 9. Garder un state local dans un projet collaboratif

Architecture fragile :

```text
Dev A → terraform.tfstate A
Dev B → terraform.tfstate B
Dev C → terraform.tfstate C
```

Chaque personne possède alors une représentation indépendante de la même infrastructure.

Le chapitre Remote State introduit un backend S3 pour centraliser cet état.

---

## 10. Modifier le backend sans migrer le state

Passer d’un backend local à S3 demande une réinitialisation adaptée.

Le cours utilise :

```bash
terraform init -migrate-state
```

Le piège est de changer uniquement le bloc `backend` et de supposer que le state suivra automatiquement sans étape de migration.

---

## 11. Versionner le mauvais contenu

Le code Terraform doit être versionné, mais le state n’est pas traité comme un simple fichier source dans un contexte collaboratif.

À distinguer :

```text
À versionner
- fichiers .tf
- modules
- documentation
- .terraform.lock.hcl

À gérer via backend
- terraform.tfstate partagé
```

Le piège est de mélanger source de code et état opérationnel.

---

## 12. Ne pas contraindre les versions de providers

Sans contrainte, une future exécution de `terraform init` peut récupérer une version différente d’un provider.

Le cours recommande :

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Le piège est de supposer qu’une configuration continuera indéfiniment à se comporter de la même façon avec « la dernière version ».

---

## 13. Déclarer la version dans le bloc provider

Le cours montre cette ancienne syntaxe comme dépréciée :

```hcl
provider "kubernetes" {
  version = "~> 2.9.0"
}
```

Terraform signale alors un avertissement.

La version doit être déclarée dans `required_providers`.

---

## 14. Négliger `terraform plan`

Un anti-pattern simple consiste à passer directement de la modification du code à :

```bash
terraform apply -auto-approve
```

sans analyser les changements.

Le cours introduit `plan` précisément pour comprendre ce que Terraform va :

- créer ;
- modifier ;
- détruire.

`-auto-approve` est utilisé pour les labs, mais ne doit pas faire oublier la valeur du contrôle préalable.

---

## 15. Supprimer manuellement une ressource gérée par Terraform

Le projet final demande explicitement de nettoyer l’infrastructure avec :

```bash
terraform destroy --auto-approve
```

Le piège consiste à créer avec Terraform puis supprimer arbitrairement dans la console AWS.

Cela crée un écart entre :

```text
State Terraform
      et
Réalité distante
```

jusqu’à ce que Terraform réévalue l’infrastructure.

---

## 16. Mettre toute l’infrastructure dans un énorme fichier

Le chapitre Modules explique qu’un projet grandissant dans un seul répertoire/fichier devient difficile à maintenir et à naviguer.

Anti-pattern :

```text
main.tf
  2000 lignes
  réseau
  calcul
  stockage
  base de données
  sécurité
  outputs
```

Le cours introduit les modules pour découper les responsabilités.

---

## 17. Copier-coller des stacks entre environnements

Sans module :

```text
DEV  → copie 1
QA   → copie 2
PROD → copie 3
```

Chaque copie peut évoluer différemment.

Le cours associe cette pratique au risque de dérive d’environnement et recommande la réutilisation via modules et variables.

---

## 18. Trop utiliser les `locals`

Le chapitre HCL explique l’intérêt des `locals`, mais précise qu’un usage excessif peut rendre le code moins lisible.

Anti-pattern :

```text
Chaque valeur passe par plusieurs locals
        ↓
La valeur réelle devient difficile à retrouver
```

Les `locals` doivent réduire la répétition, pas masquer la configuration.

---

## 19. Utiliser un provisioner alors qu’un mécanisme natif suffit

Le cours montre :

- `user_data` ;
- `local-exec` ;
- `remote-exec` ;
- `file`.

Le piège consiste à mettre toute la configuration applicative dans des `remote-exec` complexes alors qu’un bootstrap via `user_data` ou un outil dédié de configuration peut être plus cohérent avec le besoin.

Le cours présente d’ailleurs les provisioners comme un mécanisme permettant aussi d’appeler des outils comme Ansible, Chef ou Puppet.

---

## 20. Oublier que les provisioners sont liés au cycle de la ressource

Le support précise :

- exécution par défaut à la création ;
- possibilité d’utiliser `when = destroy` ;
- échec pouvant interrompre `terraform apply` ;
- `on_failure` modifiant le comportement.

Le piège est de les considérer comme des scripts réexécutés automatiquement à chaque modification.

---

## 21. Exposer trop d’informations via outputs

Les outputs doivent exposer les valeurs importantes : IP, IDs nécessaires, résultats d’un module.

Le piège est de transformer les outputs en dump complet de l’état ou d’exposer inutilement des informations sensibles.

Terraform permet :

```hcl
sensitive = true
```

pour masquer une sortie sensible dans l’interface.

---

## 22. Confondre Kubernetes Provider et Helm Provider

Le cours distingue :

```text
Provider Kubernetes
= ressources Kubernetes directes

Provider Helm
= releases / charts Helm
```

Le piège est de les considérer comme interchangeables sans comprendre le niveau d’abstraction différent.

---

## 23. Ne pas détruire les ressources des labs

Le cours répète plusieurs fois :

```bash
terraform destroy -auto-approve
```

Dans AWS, oublier le nettoyage peut conserver des ressources actives et générer des coûts.

---

## 24. Ne pas taguer les ressources dans un compte partagé

Le projet final recommande les tags afin de retrouver facilement ses ressources.

Dans un compte partagé, des noms et tags explicites évitent :

```text
Qui a créé cette instance ?
Quel projet utilise ce volume ?
Peut-on supprimer cette ressource ?
```

---

## 25. Tableau récapitulatif

| Anti-pattern / piège | Conséquence | Réflexe attendu |
|---|---|---|
| Secrets en dur | Exposition | Externaliser les credentials |
| AMI statique | Faible portabilité | Data Source |
| State local en équipe | Divergence | Backend distant |
| `depends_on` partout | Graphe artificiel | Références implicites |
| `count` mal compris | Erreurs d’index | Penser collection |
| EBS autre AZ | Attachement impossible | Même AZ |
| Provider non versionné | Reproductibilité faible | `required_providers` |
| Apply sans revue | Changements non maîtrisés | `plan` |
| Suppression manuelle | Drift | `terraform destroy` |
| Monolithe / copier-coller | Maintenance difficile | Modules |
| Provisioners complexes | Fragilité | Utiliser le mécanisme adapté |
| Ressources non taguées | Identification difficile | Tags explicites |

---

## 26. À retenir

Les erreurs Terraform du cours se regroupent autour de cinq catégories :

```text
SÉCURITÉ
STATE
DÉPENDANCES
CARDINALITÉ
MAINTENABILITÉ
```

Comprendre ces pièges permet de passer d’un simple script IaC qui « fonctionne une fois » à une configuration **reproductible, compréhensible et réutilisable**.

---

## Source pédagogique

Synthèse fondée sur les sept supports Terraform DataScientest du Sprint 17, notamment les avertissements, erreurs rencontrées dans les labs, contraintes du Remote State, comportement de `count`, remarques sur les provisioners et conditions de validation du projet final.