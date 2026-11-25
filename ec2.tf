# ==============================================================================
# AMI oficial más reciente de Ubuntu 24.04 LTS (usuario SSH: ubuntu)
# ==============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# Security Group (Firewall de la EC2)
# ==============================================================================

resource "aws_security_group" "aguafix_sg" {
  name        = "${var.project_name}-sg"
  description = "Permite acceso SSH (22), HTTP (80) y HTTPS (443) para AguaFix"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (opcional)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida a Internet (Docker Hub, apt, No-IP, SMTP, S3)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ==============================================================================
# Par de llaves SSH (solo usa la llave pública; la privada nunca se sube)
# ==============================================================================

resource "aws_key_pair" "aguafix_key" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ==============================================================================
# Instancia EC2
# ==============================================================================

resource "aws_instance" "aguafix" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.aguafix_key.key_name
  vpc_security_group_ids      = [aws_security_group.aguafix_sg.id]
  associate_public_ip_address = true

  # Recrea la instancia si cambia el script user_data.sh.tftpl
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    compose_dir           = var.compose_dir
    docker_image          = var.docker_image
    noip_hostname         = var.noip_hostname
    noip_username         = var.noip_username
    noip_password         = var.noip_password
    db_name               = var.db_name
    db_user               = var.db_user
    db_password           = var.db_password
    mail_host             = var.mail_host
    mail_port             = var.mail_port
    mail_user             = var.mail_user
    mail_password         = var.mail_password
    mail_from             = var.mail_from
    maintenance_email     = var.maintenance_email
    jwt_secret            = var.jwt_secret
    aws_region            = var.aws_region
    aws_s3_bucket         = aws_s3_bucket.images.bucket
    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
  })

  depends_on = [aws_s3_bucket.images]

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
