# Projet final Terraform — Index

Ce répertoire regroupe les livrables du projet final Terraform du Sprint 17.

## Documentation

- `192.07_SPECIFICATIONS_PROJET_FINAL.md` — exigences du sujet ;
- `192.07_ARCHITECTURE_WORDPRESS_AWS.md` — architecture cible ;
- `192.07_CORRIGE_PROJET_FINAL.md` — corrigé et mode d'emploi ;
- `192.07_CHECKLIST_VALIDATION.md` — checklist de validation ;
- `192.07_TESTS_ET_VALIDATION.md` — stratégie de tests ;
- `192.07_RETOUR_EXPERIENCE.md` — retour d'implémentation et points à observer lors du vrai déploiement.

## Code exécutable

Le projet Terraform réellement implémenté se trouve dans :

```text
wordpress-aws/
```

Il contient quatre modules :

```text
networking
rds
ec2
ebs
```

ainsi qu'un workflow GitHub Actions de validation statique.

## État de qualification

La CI vérifie avec Terraform 1.9.8 :

- `terraform fmt -check -diff -recursive` ;
- `terraform init -backend=false` ;
- `terraform validate` ;
- syntaxe Bash du bootstrap ;
- absence de motif évident de clé AWS dans le projet.

La qualification AWS end-to-end reste volontairement distincte : elle nécessite un compte AWS autorisé, un `terraform apply`, un test WordPress réel puis un `terraform destroy`.
