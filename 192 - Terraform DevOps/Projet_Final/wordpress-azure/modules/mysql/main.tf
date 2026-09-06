data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "mysql_admin" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault" "this" {
  name                       = substr(replace("${var.project_name}-${random_string.suffix.result}-kv", "_", "-"), 0, 24)
  location                   = var.location
  resource_group_name        = var.resource_group
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags
}

resource "azurerm_mysql_flexible_server" "this" {
  name                   = "${var.project_name}-${var.environment}-${random_string.suffix.result}-mysql"
  resource_group_name    = var.resource_group
  location               = var.location
  administrator_login    = var.admin_username
  administrator_password = random_password.mysql_admin.result
  sku_name               = var.sku_name
  version                = "8.0.21"
  zone                   = var.primary_zone

  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  dynamic "high_availability" {
    for_each = var.enable_ha ? [1] : []

    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.standby_zone
    }
  }

  storage {
    size_gb           = var.storage_gb
    auto_grow_enabled = true
  }

  tags = var.tags
}

resource "azurerm_mysql_flexible_database" "wordpress" {
  name                = var.database_name
  resource_group_name = var.resource_group
  server_name         = azurerm_mysql_flexible_server.this.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_key_vault_secret" "mysql_password" {
  name         = "mysql-admin-password"
  value        = random_password.mysql_admin.result
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_key_vault.this]
}
