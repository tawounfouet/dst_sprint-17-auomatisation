output "vm_id" {
  value = azurerm_linux_virtual_machine.wordpress.id
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.wordpress.name
}

output "public_ip" {
  value = azurerm_public_ip.this.ip_address
}

output "fqdn" {
  value = azurerm_public_ip.this.fqdn
}

output "principal_id" {
  value = azurerm_linux_virtual_machine.wordpress.identity[0].principal_id
}
