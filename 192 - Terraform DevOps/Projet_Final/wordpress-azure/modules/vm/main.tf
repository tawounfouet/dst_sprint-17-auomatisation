resource "random_string" "dns" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_public_ip" "this" {
  name                = "${var.project_name}-${var.environment}-pip"
  resource_group_name = var.resource_group
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
  domain_name_label   = substr(replace("${var.project_name}-${var.environment}-${random_string.dns.result}", "_", "-"), 0, 63)
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  name                = "${var.project_name}-${var.environment}-nic"
  resource_group_name = var.resource_group
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_linux_virtual_machine" "wordpress" {
  name                = "${var.project_name}-${var.environment}-vm"
  resource_group_name = var.resource_group
  location            = var.location
  size                = var.vm_size
  zone                = var.zone
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.this.id]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-noble"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.project_name}-${var.environment}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  custom_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    mysql_fqdn           = var.mysql_fqdn
    mysql_database_name  = var.mysql_database_name
    mysql_admin_username = var.mysql_admin_username
    key_vault_uri        = var.key_vault_uri
    db_secret_name       = var.db_secret_name
    enable_https         = var.enable_https
  }))

  tags = var.tags
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.wordpress.identity[0].principal_id
}
