variable "project_name" { type = string }
variable "environment" { type = string }
variable "resource_group" { type = string }
variable "location" { type = string }
variable "zone" { type = string }
variable "vm_id" { type = string }
variable "disk_size_gb" { type = number }
variable "tags" { type = map(string) }
