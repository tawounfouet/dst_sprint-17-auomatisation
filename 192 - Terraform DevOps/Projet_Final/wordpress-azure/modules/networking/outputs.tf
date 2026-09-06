output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "app_subnet_id" {
  value = azurerm_subnet.app.id
}

output "db_subnet_id" {
  value = azurerm_subnet.db.id
}

output "web_nsg_id" {
  value = azurerm_network_security_group.web.id
}

output "mysql_private_dns_zone_id" {
  value = azurerm_private_dns_zone.mysql.id
}
