variable "subscription_id" {
  description = "Identifiant de l'abonnement Azure cible."
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Région Azure cible. La variante choisit France Central."
  type        = string
  default     = "francecentral"
}

variable "project_name" {
  description = "Préfixe de nommage des ressources."
  type        = string
  default     = "dst-s17-wordpress"
}

variable "environment" {
  description = "Environnement logique."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment doit valoir dev, test ou prod."
  }
}

variable "vnet_cidr" {
  description = "CIDR du Virtual Network Azure."
  type        = string
  default     = "10.30.0.0/16"
}

variable "app_subnet_cidr" {
  description = "CIDR du subnet applicatif WordPress."
  type        = string
  default     = "10.30.10.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR du subnet privé délégué à MySQL Flexible Server."
  type        = string
  default     = "10.30.110.0/24"
}

variable "vm_size" {
  description = "SKU de la VM WordPress."
  type        = string
  default     = "Standard_B1s"
}

variable "vm_zone" {
  description = "Availability Zone de la VM et du disque de données."
  type        = string
  default     = "1"
}

variable "admin_username" {
  description = "Utilisateur administrateur Linux."
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "Clé publique SSH OpenSSH utilisée par la VM."
  type        = string
  sensitive   = true
}

variable "ssh_cidr" {
  description = "CIDR autorisé à accéder en SSH. Null désactive l'ouverture du port 22."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_https" {
  description = "Active le bonus HTTPS pédagogique avec certificat auto-signé."
  type        = bool
  default     = false
}

variable "mysql_sku_name" {
  description = "SKU Azure Database for MySQL Flexible Server. La valeur par défaut permet la haute disponibilité zonale."
  type        = string
  default     = "GP_Standard_D2ds_v4"
}

variable "mysql_primary_zone" {
  description = "Zone principale MySQL."
  type        = string
  default     = "1"
}

variable "mysql_standby_zone" {
  description = "Zone de secours MySQL lorsque la HA est activée."
  type        = string
  default     = "2"
}

variable "mysql_enable_ha" {
  description = "Active la haute disponibilité ZoneRedundant de MySQL Flexible Server."
  type        = bool
  default     = true
}

variable "mysql_admin_username" {
  description = "Compte administrateur MySQL. Le mot de passe est généré automatiquement."
  type        = string
  default     = "wordpressadmin"
}

variable "mysql_database_name" {
  description = "Nom de la base WordPress."
  type        = string
  default     = "wordpress"
}

variable "mysql_storage_gb" {
  description = "Taille du stockage MySQL en GiB."
  type        = number
  default     = 32
}

variable "extra_disk_size_gb" {
  description = "Taille du Managed Disk supplémentaire, analogue à l'EBS du sujet AWS."
  type        = number
  default     = 10

  validation {
    condition     = var.extra_disk_size_gb == 10
    error_message = "La transposition conserve le disque supplémentaire de 10 GiB du sujet d'origine."
  }
}

variable "tags" {
  description = "Tags Azure complémentaires."
  type        = map(string)
  default     = {}
}
