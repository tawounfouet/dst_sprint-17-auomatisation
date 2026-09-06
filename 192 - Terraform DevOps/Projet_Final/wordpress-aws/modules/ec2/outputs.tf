output "instance_id" {
  value = aws_instance.wordpress.id
}

output "availability_zone" {
  value = aws_instance.wordpress.availability_zone
}

output "public_ip" {
  value = aws_instance.wordpress.public_ip
}

output "public_dns" {
  value = aws_instance.wordpress.public_dns
}

output "ami_id" {
  value = data.aws_ami.ubuntu.id
}
