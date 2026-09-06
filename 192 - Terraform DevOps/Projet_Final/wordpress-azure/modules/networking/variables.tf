variable "project_name" { type = string }
variable "environment" { type = string }
variable "resource_group" { type = string }
variable "location" { type = string }
variable "vnet_cidr" { type = string }
variable "app_subnet_cidr" { type = string }
variable "db_subnet_cidr" { type = string }
variable "ssh_cidr" {
  type     = string
  default  = null
  nullable = true
}
variable "enable_https" { type = bool }
variable "tags" { type = map(string) }
