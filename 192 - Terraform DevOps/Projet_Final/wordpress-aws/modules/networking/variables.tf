variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_db_subnet_cidrs" {
  type = list(string)
}

variable "ssh_cidr" {
  type     = string
  default  = null
  nullable = true
}

variable "enable_https" {
  type    = bool
  default = false
}
