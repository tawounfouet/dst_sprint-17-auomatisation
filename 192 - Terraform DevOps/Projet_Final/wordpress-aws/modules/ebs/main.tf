resource "aws_ebs_volume" "wordpress_data" {
  availability_zone = var.availability_zone
  size              = var.volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project_name}-wordpress-data"
  }
}

resource "aws_volume_attachment" "wordpress_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.wordpress_data.id
  instance_id = var.instance_id
}
