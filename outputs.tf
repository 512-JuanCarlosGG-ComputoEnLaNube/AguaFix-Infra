output "ec2_public_ip" {
  description = "Dirección IP pública de la instancia EC2"
  value       = aws_instance.aguafix.public_ip
}

output "app_url" {
  description = "URL pública de la API usando el dominio de No-IP"
  value       = "http://${var.noip_hostname}/"
}

output "ssh_command" {
  description = "Comando SSH listo para conectarse a la instancia EC2"
  value       = "ssh -i aguafix-key.pem ubuntu@${aws_instance.aguafix.public_ip}"
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 creado para imágenes"
  value       = aws_s3_bucket.images.bucket
}

output "s3_bucket_base_url" {
  description = "URL base pública del bucket S3"
  value       = "https://${aws_s3_bucket.images.bucket}.s3.${var.aws_region}.amazonaws.com/"
}
