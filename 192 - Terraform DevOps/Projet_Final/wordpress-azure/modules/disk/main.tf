resource "azurerm_managed_disk" "wordpress_data" {
  name                 = "${var.project_name}-${var.environment}-data"
  location             = var.location
  resource_group_name  = var.resource_group
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.disk_size_gb
  zone                 = var.zone
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "wordpress_data" {
  managed_disk_id    = azurerm_managed_disk.wordpress_data.id
  virtual_machine_id = var.vm_id
  lun                = 0
  caching            = "ReadWrite"
}
