output "disk_id" {
  value = azurerm_managed_disk.wordpress_data.id
}

output "disk_name" {
  value = azurerm_managed_disk.wordpress_data.name
}
