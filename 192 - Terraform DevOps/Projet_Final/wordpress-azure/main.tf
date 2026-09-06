locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Sprint      = "17-Automatisation"
      Cloud       = "Azure"
    },
    var.tags
  )
}

resource "azurerm_resource_group" "this" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location
  tags     = local.common_tags
}

module "networking" {
  source = "./modules/networking"

  project_name    = var.project_name
  environment     = var.environment
  resource_group  = azurerm_resource_group.this.name
  location        = azurerm_resource_group.this.location
  vnet_cidr       = var.vnet_cidr
  app_subnet_cidr = var.app_subnet_cidr
  db_subnet_cidr  = var.db_subnet_cidr
  ssh_cidr        = var.ssh_cidr
  enable_https    = var.enable_https
  tags            = local.common_tags
}

module "mysql" {
  source = "./modules/mysql"

  project_name        = var.project_name
  environment         = var.environment
  resource_group      = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  delegated_subnet_id = module.networking.db_subnet_id
  private_dns_zone_id = module.networking.mysql_private_dns_zone_id
  sku_name            = var.mysql_sku_name
  primary_zone        = var.mysql_primary_zone
  standby_zone        = var.mysql_standby_zone
  enable_ha           = var.mysql_enable_ha
  admin_username      = var.mysql_admin_username
  database_name       = var.mysql_database_name
  storage_gb          = var.mysql_storage_gb
  tags                = local.common_tags

  depends_on = [module.networking]
}

module "vm" {
  source = "./modules/vm"

  project_name         = var.project_name
  environment          = var.environment
  resource_group       = azurerm_resource_group.this.name
  location             = azurerm_resource_group.this.location
  subnet_id            = module.networking.app_subnet_id
  vm_size              = var.vm_size
  zone                 = var.vm_zone
  admin_username       = var.admin_username
  ssh_public_key       = var.ssh_public_key
  mysql_fqdn           = module.mysql.fqdn
  mysql_database_name  = var.mysql_database_name
  mysql_admin_username = var.mysql_admin_username
  key_vault_id         = module.mysql.key_vault_id
  key_vault_uri        = module.mysql.key_vault_uri
  db_secret_name       = module.mysql.db_secret_name
  enable_https         = var.enable_https
  tags                 = local.common_tags
}

module "disk" {
  source = "./modules/disk"

  project_name   = var.project_name
  environment    = var.environment
  resource_group = azurerm_resource_group.this.name
  location       = azurerm_resource_group.this.location
  zone           = var.vm_zone
  vm_id          = module.vm.vm_id
  disk_size_gb   = var.extra_disk_size_gb
  tags           = local.common_tags
}
