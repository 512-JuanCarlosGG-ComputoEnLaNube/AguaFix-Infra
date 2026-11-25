# ==============================================================================
# Variables de Infraestructura AWS
# ==============================================================================

variable "project_name" {
  description = "Nombre base del proyecto para nombrar recursos y etiquetas"
  type        = string
  default     = "aguafix"
}

variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 (ej. t3.micro o t2.micro para capa gratuita)"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key_path" {
  description = "Ruta local al archivo de llave pública SSH (.pub) que se registrará en AWS"
  type        = string
  default     = "./aguafix-key.pem.pub"
}

variable "s3_bucket_name" {
  description = "Nombre único global del bucket S3 para las imágenes de reportes"
  type        = string
}

variable "compose_dir" {
  description = "Ruta fija en la EC2 donde vivirá compose.yaml (acordada con Persona 1 y 3)"
  type        = string
  default     = "/home/ubuntu/aguafix"
}

variable "docker_image" {
  description = "Imagen de Docker Hub de la API de AguaFix"
  type        = string
  default     = "deborahvp/aguafix-api:latest"
}

# ==============================================================================
# Variables de No-IP (usadas en user_data.sh.tftpl por Persona 3)
# ==============================================================================

variable "noip_hostname" {
  description = "Hostname dinámico registrado en No-IP (ej. aguafix-equipo.ddns.net)"
  type        = string
}

variable "noip_username" {
  description = "Usuario o correo de la cuenta de No-IP"
  type        = string
  sensitive   = true
}

variable "noip_password" {
  description = "Contraseña o DDNS Key de la cuenta de No-IP"
  type        = string
  sensitive   = true
}

# ==============================================================================
# Variables de Base de Datos PostgreSQL (para .env en la EC2)
# ==============================================================================

variable "db_name" {
  description = "Nombre de la base de datos PostgreSQL"
  type        = string
  default     = "aguafix_db"
}

variable "db_user" {
  description = "Usuario de la base de datos PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Contraseña de la base de datos PostgreSQL"
  type        = string
  sensitive   = true
}

# ==============================================================================
# Variables de Correo SMTP (para .env en la EC2)
# ==============================================================================

variable "mail_host" {
  description = "Servidor SMTP para envío de correos"
  type        = string
  default     = "smtp.gmail.com"
}

variable "mail_port" {
  description = "Puerto del servidor SMTP"
  type        = number
  default     = 587
}

variable "mail_user" {
  description = "Usuario/correo para autenticarse en SMTP"
  type        = string
  sensitive   = true
}

variable "mail_password" {
  description = "Contraseña o App Password de SMTP"
  type        = string
  sensitive   = true
}

variable "mail_from" {
  description = "Dirección remitente de los correos"
  type        = string
}

variable "maintenance_email" {
  description = "Correo de mantenimiento que recibe los reportes"
  type        = string
}

# ==============================================================================
# Variables de Seguridad y Credenciales AWS para la API (S3 en StorageService)
# ==============================================================================

variable "jwt_secret" {
  description = "Clave secreta para firmar tokens JWT"
  type        = string
  sensitive   = true
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID que usará la API para subir imágenes a S3"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key que usará la API para subir imágenes a S3"
  type        = string
  sensitive   = true
}
