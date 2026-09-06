output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Resource Group contenant le projet."
}

output "wordpress_public_ip" {
  value       = module.vm.public_ip
  description = "Adresse IP publique de la VM WordPress."
}

output "wordpress_fqdn" {
  value       = module.vm.fqdn
  description = "FQDN public Azure de la VM."
}

output "wordpress_url" {
  value       = "http://${module.vm.fqdn}"
  description = "URL HTTP de WordPress."
}

output "wordpress_https_url" {
  value       = var.enable_https ? "https://${module.vm.fqdn}" : null
  description = "URL HTTPS pédagogique lorsque enable_https=true."
}

output "mysql_fqdn" {
  value       = module.mysql.fqdn
  description = "FQDN privé du serveur Azure Database for MySQL Flexible Server."
}

output "key_vault_name" {
  value       = module.mysql.key_vault_name
  description = "Nom du Key Vault hébergeant le mot de passe MySQL."
}

output "extra_managed_disk_id" {
  value       = module.disk.disk_id
  description = "Identifiant du Managed Disk supplémentaire de 10 GiB."
}
