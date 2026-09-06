output "server_id" {
  value = azurerm_mysql_flexible_server.this.id
}

output "server_name" {
  value = azurerm_mysql_flexible_server.this.name
}

output "fqdn" {
  value = azurerm_mysql_flexible_server.this.fqdn
}

output "database_name" {
  value = azurerm_mysql_flexible_database.wordpress.name
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "db_secret_name" {
  value = azurerm_key_vault_secret.mysql_password.name
}
