# AWS / GitHub Actions — Authentification pour la qualification Terraform

Ce document décrit les deux mécanismes pris en charge par les workflows de qualification du projet final Terraform.

## 1. Méthode recommandée : GitHub OIDC

L'objectif est d'éviter des clés AWS longues durées dans GitHub.

GitHub Actions reçoit un jeton OIDC éphémère et assume un rôle IAM AWS autorisé uniquement pour ce repository.

Flux :

```text
GitHub Actions
    ↓ OIDC token
AWS IAM Identity Provider
    ↓ AssumeRoleWithWebIdentity
IAM Role de qualification
    ↓
AWS eu-west-3
```

### Côté AWS

Il faut disposer :

1. du provider OIDC GitHub `token.actions.githubusercontent.com` dans le compte AWS ;
2. d'un rôle IAM dédié ;
3. d'une trust policy limitée au repository :

```text
tawounfouet/dst_sprint-17-auomatisation
```

Exemple conceptuel de condition :

```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:tawounfouet/dst_sprint-17-auomatisation:*"
  },
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  }
}
```

Le rôle doit disposer des autorisations nécessaires au lab Terraform : VPC/EC2/EBS, RDS, IAM instance role/profile utilisé par l'EC2, et les opérations liées au mot de passe RDS géré par AWS Secrets Manager.

Utiliser un compte sandbox ou un rôle dédié de qualification plutôt qu'une identité de production.

### Côté GitHub

Dans le repository :

```text
Settings
→ Secrets and variables
→ Actions
→ New repository secret
```

Créer :

```text
Name  : AWS_ROLE_ARN
Value : arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>
```

Ne jamais committer l'ARN comme substitut à une politique de contrôle d'accès ; le secret est utilisé ici surtout pour centraliser la configuration du workflow.

## 2. Méthode fallback : access keys

Si le compte de lab ne permet pas la configuration OIDC, les workflows acceptent :

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Pour des credentials STS temporaires, ajouter :

```text
AWS_SESSION_TOKEN
```

Créer ces valeurs uniquement dans :

```text
GitHub repository
→ Settings
→ Secrets and variables
→ Actions
```

Ne jamais créer de fichier contenant ces valeurs dans le repository.

## 3. Credentials des supports DataScientest

Les supports pédagogiques historiques contiennent des identifiants de compte partagé.

Ils ne sont volontairement **pas recopiés** dans le code ni dans cette documentation.

Avant toute utilisation d'un compte pédagogique partagé, vérifier :

- que les credentials sont encore valides ;
- que l'utilisation actuelle est toujours autorisée ;
- que les permissions permettent le périmètre du projet ;
- qu'aucune ressource appartenant à un autre apprenant ne sera modifiée ou détruite.

Les workflows et modules du repository n'ont aucune dépendance à ces credentials historiques.

## 4. Premier gate : AWS Plan

Une fois l'identité configurée, ouvrir :

```text
GitHub → Actions → Terraform Project Final - AWS Plan
```

Puis exécuter le workflow si nécessaire avec `Run workflow`.

Le gate attendu :

```text
Require an AWS authentication method  ✅
Configure AWS credentials             ✅
Confirm AWS identity                  ✅
Terraform format check                ✅
Terraform init                        ✅
Terraform validate                    ✅
Terraform real AWS plan               ✅
Upload qualification plan             ✅
```

Ne pas lancer l'E2E tant que ce plan n'est pas vert.

## 5. Second gate : E2E

Une fois le plan vert :

```text
GitHub → Actions
→ Terraform Project Final - AWS E2E Qualification
→ Run workflow
```

Saisir exactement :

```text
QUALIFY
```

Le workflow crée alors temporairement l'infrastructure, exécute les contrôles et termine par `terraform destroy`.

## 6. Vérification après le run

Même si le step `terraform destroy` est vert, vérifier dans le compte AWS de qualification qu'il ne reste aucune ressource créée avec le préfixe :

```text
dst-s17-wordpress
```

Contrôler au minimum :

- EC2 Instances ;
- EBS Volumes ;
- RDS Databases ;
- VPC ;
- Security Groups ;
- IAM role / instance profile ;
- secrets éventuellement créés pour le master RDS.

## 7. Principe de sécurité

```text
Pas de credential AWS
       dans Git
          │
          ├── OIDC recommandé
          │
          └── GitHub Secrets en fallback
```

Le repository reste ainsi publiable sans divulguer d'identifiants AWS.
