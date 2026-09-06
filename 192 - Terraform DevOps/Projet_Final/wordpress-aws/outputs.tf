output "availability_zones" {
  description = "Availability Zones sélectionnées dynamiquement pour le projet."
  value       = local.selected_azs
}

output "vpc_id" {
  description = "Identifiant du VPC."
  value       = module.networking.vpc_id
}

output "wordpress_public_ip" {
  description = "Adresse IP publique de l'instance WordPress."
  value       = module.ec2.public_ip
}

output "wordpress_public_dns" {
  description = "DNS public de l'instance WordPress."
  value       = module.ec2.public_dns
}

output "wordpress_url" {
  description = "URL HTTP de WordPress."
  value       = "http://${module.ec2.public_dns}"
}

output "wordpress_https_url" {
  description = "URL HTTPS pédagogique lorsque enable_https=true."
  value       = var.enable_https ? "https://${module.ec2.public_dns}" : null
}

output "rds_endpoint" {
  description = "Endpoint RDS utilisé par WordPress."
  value       = module.rds.endpoint
}

output "rds_master_user_secret_arn" {
  description = "ARN du secret AWS Secrets Manager géré par RDS."
  value       = module.rds.master_user_secret_arn
}

output "extra_ebs_volume_id" {
  description = "Identifiant du volume EBS supplémentaire de 10 GiB."
  value       = module.ebs.volume_id
}
