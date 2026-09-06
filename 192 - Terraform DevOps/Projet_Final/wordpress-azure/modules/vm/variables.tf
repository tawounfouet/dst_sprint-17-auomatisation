variable "project_name" { type = string }
variable "environment" { type = string }
variable "resource_group" { type = string }
variable "location" { type = string }
variable "subnet_id" { type = string }
variable "vm_size" { type = string }
variable "zone" { type = string }
variable "admin_username" { type = string }
variable "ssh_public_key" {
  type      = string
  sensitive = true
}
variable "mysql_fqdn" { type = string }
variable "mysql_database_name" { type = string }
variable "mysql_admin_username" { type = string }
variable "key_vault_id" { type = string }
variable "key_vault_uri" { type = string }
variable "db_secret_name" { type = string }
variable "enable_https" { type = bool }
variable "tags" { type = map(string) }
