variable "project_name" {
  type = string
}

variable "region" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "key_name" {
  type     = string
  default  = null
  nullable = true
}

variable "db_endpoint" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "enable_https" {
  type    = bool
  default = false
}
