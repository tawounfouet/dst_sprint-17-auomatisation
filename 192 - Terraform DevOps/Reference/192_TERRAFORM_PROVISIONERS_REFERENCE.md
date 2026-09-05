# 192 — Terraform Provisioners Reference

> Sprint 17 — Automatisation  
> Module : Terraform DevOps  
> Référence issue du chapitre **192.04 — Données utilisateurs et sources de données**.

## 1. Définition

Les **provisioners** Terraform permettent d’exécuter des actions locales ou distantes lors du cycle de vie d’une ressource.

Le support les présente notamment pour :

- exécuter une commande sur la machine qui lance Terraform ;
- copier des fichiers vers une machine distante ;
- exécuter des commandes à distance ;
- déclencher un outil de configuration tel qu’Ansible, Chef ou Puppet.

---

## 2. Emplacement

Un provisioner est déclaré dans une ressource :

```hcl
resource "aws_instance" "datascientest_instance" {
  ami           = var.image_id
  instance_type = var.type_instance

  provisioner "local-exec" {
    command = "echo ${self.public_ip} > file.txt"
  }
}
```

---

## 3. Objet `self`

Le support utilise `self` pour référencer la ressource parente depuis un bloc provisioner.

Exemple :

```hcl
self.public_ip
```

L’idée à retenir :

```text
self → ressource qui contient le provisioner
```

---

## 4. Exécution à la création

Par défaut, dans les exemples du cours, un provisioner s’exécute lors de la création de la ressource.

Le support explique qu’en cas d’échec lors de cette phase, la ressource peut être considérée comme incomplètement configurée et être recréée lors d’une prochaine application.

---

## 5. Provisioner à la destruction

```hcl
provisioner "local-exec" {
  when    = destroy
  command = "echo 'Provisionneur de suppression'"
}
```

`when = destroy` permet d’exécuter l’action avant la suppression de la ressource.

---

## 6. Plusieurs provisioners

Ils peuvent être enchaînés dans une même ressource :

```hcl
provisioner "local-exec" {
  command = "echo premier"
}

provisioner "local-exec" {
  command = "echo second"
}
```

Le support indique qu’ils sont exécutés dans l’ordre de déclaration.

---

## 7. Gestion d’échec

Le paramètre `on_failure` est présenté avec deux valeurs :

```text
fail      → arrêter sur erreur
continue  → poursuivre malgré l’erreur
```

Exemple :

```hcl
provisioner "local-exec" {
  command    = "echo IP address is ${self.private_ip}"
  on_failure = continue
}
```

---

## 8. `local-exec`

Exécute une commande sur la machine où Terraform est exécuté.

```hcl
provisioner "local-exec" {
  command = "echo ${self.public_ip} >> public_ip.txt"
}
```

Arguments mentionnés dans le cours :

- `command` ;
- `working_dir` ;
- `interpreter` ;
- `environment` ;
- `when`.

---

## 9. `file`

Copie un fichier vers une ressource distante.

```hcl
provisioner "file" {
  source      = "configuration.conf"
  destination = "/home/ec2-user/configuration.conf"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/path/to/key.pem")
    host        = self.public_ip
  }
}
```

Le support montre aussi une connexion par mot de passe.

---

## 10. `remote-exec`

Exécute des commandes sur une machine distante.

```hcl
resource "aws_instance" "web" {
  ami           = var.image_id
  instance_type = var.type_instance

  connection {
    type = "ssh"
    user = "ec2-user"
    host = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update",
      "sudo yum install -y httpd",
      "sudo systemctl enable --now httpd"
    ]
  }
}
```

Le support cite trois modes :

```text
inline
script
scripts
```

---

## 11. `file` + `remote-exec`

Le cours montre une combinaison pour transmettre un script puis l’exécuter avec des arguments :

```hcl
provisioner "file" {
  source      = "datascientest-script.sh"
  destination = "/tmp/datascientest-script.sh"
}

provisioner "remote-exec" {
  inline = [
    "chmod +x /tmp/datascientest-script.sh",
    "/tmp/datascientest-script.sh args"
  ]
}
```

---

## 12. Provisioner vs `user_data`

Le même chapitre présente également `user_data` pour le bootstrap d’une instance EC2.

```hcl
user_data = file("install_apache.sh")
```

Distinction pédagogique :

```text
user_data
→ instructions transmises au lancement de l’instance

provisioner
→ action exécutée par Terraform localement ou à distance
```

---

## 13. Connexion distante

Les exemples du support utilisent principalement SSH :

```hcl
connection {
  type        = "ssh"
  user        = "ec2-user"
  private_key = file("key.pem")
  host        = self.public_ip
}
```

Le cours mentionne également WinRM comme mécanisme pris en charge pour les connexions distantes.

---

## 14. Mémo

```text
local-exec  → commande locale
file        → transfert de fichier
remote-exec → commande distante
self        → ressource parente
when        → moment d’exécution
on_failure  → comportement sur erreur
```

---

## Source pédagogique

Support DataScientest : **Terraform — Données utilisateurs et sources de données**, section Provisionneurs.