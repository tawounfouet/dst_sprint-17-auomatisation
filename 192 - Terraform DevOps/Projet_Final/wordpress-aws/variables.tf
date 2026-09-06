variable "region" {
  description = "Région AWS cible. Le projet DataScientest impose Paris."
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Préfixe commun utilisé pour nommer les ressources."
  type        = string
  default     = "dst-s17-wordpress"
}

variable "environment" {
  description = "Nom logique de l'environnement."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment doit valoir dev, test ou prod."
  }
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Deux sous-réseaux publics, un par Availability Zone."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.20.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Deux sous-réseaux publics sont attendus."
  }
}

variable "private_db_subnet_cidrs" {
  description = "Deux sous-réseaux privés dédiés à RDS, dans deux AZ distinctes."
  type        = list(string)
  default     = ["10.20.110.0/24", "10.20.120.0/24"]

  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2
    error_message = "Deux sous-réseaux privés DB sont nécessaires pour le Multi-AZ RDS."
  }
}

variable "instance_type" {
  description = "Type de l'instance EC2 WordPress."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nom optionnel d'une paire de clés EC2 existante. Laisser null si SSH n'est pas utilisé."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_cidr" {
  description = "CIDR autorisé à accéder en SSH. Laisser null pour ne pas ouvrir le port 22."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_https" {
  description = "Active le bonus HTTPS pédagogique avec certificat auto-signé."
  type        = bool
  default     = false
}

variable "db_instance_class" {
  description = "Classe de l'instance RDS demandée dans l'exercice."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nom logique de la base WordPress."
  type        = string
  default     = "wordpress"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.db_name))
    error_message = "db_name doit commencer par une lettre et ne contenir que lettres, chiffres et underscores."
  }
}

variable "db_username" {
  description = "Utilisateur maître RDS. Le mot de passe est généré et géré par AWS Secrets Manager."
  type        = string
  default     = "wordpress_admin"
}

variable "db_allocated_storage" {
  description = "Stockage RDS en GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "Le lab utilise au minimum 20 GiB pour RDS."
  }
}

variable "extra_ebs_size" {
  description = "Taille du disque EBS supplémentaire imposé par le sujet."
  type        = number
  default     = 10

  validation {
    condition     = var.extra_ebs_size == 10
    error_message = "Le sujet DataScientest impose un volume EBS supplémentaire de 10 GiB."
  }
}

variable "tags" {
  description = "Tags supplémentaires appliqués aux ressources."
  type        = map(string)
  default     = {}
}
