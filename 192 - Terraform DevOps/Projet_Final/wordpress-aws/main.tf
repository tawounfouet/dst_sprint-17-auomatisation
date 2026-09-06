data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Sprint      = "17-Automatisation"
    },
    var.tags
  )
}

module "networking" {
  source = "./modules/networking"

  project_name            = var.project_name
  vpc_cidr                = var.vpc_cidr
  availability_zones      = local.selected_azs
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_db_subnet_cidrs = var.private_db_subnet_cidrs
  ssh_cidr                = var.ssh_cidr
  enable_https            = var.enable_https
}

module "rds" {
  source = "./modules/rds"

  project_name      = var.project_name
  subnet_ids        = module.networking.private_db_subnet_ids
  security_group_id = module.networking.db_security_group_id
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  allocated_storage = var.db_allocated_storage
}

module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  region            = var.region
  instance_type     = var.instance_type
  subnet_id         = module.networking.public_subnet_ids[0]
  security_group_id = module.networking.web_security_group_id
  key_name          = var.key_name
  db_endpoint       = module.rds.endpoint
  db_name           = var.db_name
  db_username       = var.db_username
  db_secret_arn     = module.rds.master_user_secret_arn
  enable_https      = var.enable_https
}

module "ebs" {
  source = "./modules/ebs"

  project_name      = var.project_name
  availability_zone = module.ec2.availability_zone
  instance_id       = module.ec2.instance_id
  volume_size       = var.extra_ebs_size
}
