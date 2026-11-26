# AguaFix-Infra

Infraestructura como código (Terraform) para desplegar la API de **AguaFix** en AWS con aprovisionamiento automático en EC2, almacenamiento público de imágenes en S3 y actualización dinámica de dominio mediante No-IP.

## Arquitectura aprovisionada

- **EC2 (Ubuntu 24.04 LTS)**: instala Docker Engine y `docker-compose-plugin`, agrega `ubuntu` al grupo `docker`, consulta su IP pública vía IMDSv2, actualiza No-IP y levanta el stack en `/home/ubuntu/aguafix`.
- **Contenedores (`compose.yaml`)**:
  - `postgres` (`postgres:16-alpine`) con volumen persistente `postgres_data` y healthcheck `pg_isready`.
  - `api` (`deborahvp/aguafix-api:latest`) expuesta en `80:3000` (`PORT=3000` dentro del contenedor para coincidir con NestJS y `EXPOSE 3000`).
- **S3**: bucket con `force_destroy = true` y política de lectura pública (`s3:GetObject`) para las fotos de reportes.
- **Security Group**: puertos `22` (SSH), `80` (HTTP) y `443` (HTTPS).

## Estructura del repositorio

| Archivo | Propósito |
|---|---|
| `provider.tf` | Proveedor AWS (`~> 5.0`) y etiquetas por defecto |
| `variables.tf` | Variables de infraestructura, No-IP, BD, SMTP, JWT y S3 (secretos marcados `sensitive = true`) |
| `ec2.tf` | AMI Ubuntu 24.04, Security Group, Key Pair y EC2 con `templatefile("user_data.sh.tftpl", ...)` |
| `s3.tf` | Bucket S3 de imágenes y política de lectura pública |
| `outputs.tf` | Outputs de IP pública, URL de No-IP, comando SSH y URL base de S3 |
| `user_data.sh.tftpl` | Script completo de aprovisionamiento automático en primer arranque |
| `terraform.tfvars.example` | Plantilla de variables (copiar localmente a `terraform.tfvars`) |
| `scripts/test-noip.sh` | Prueba manual de actualización dinámica en No-IP (Paso 1) |
| `scripts/verify-e2e.sh` | Verificación End-to-End de salud, auth JWT, subida a S3 y PostgreSQL (Paso 5) |
| `.gitattributes` | Fuerza terminaciones `LF` en `*.sh`, `*.tftpl` y `*.yaml` para compatibilidad con Ubuntu |

## Despliegue rápido

1. Copia la plantilla de variables y completa tus credenciales reales (el archivo `terraform.tfvars` está ignorado por Git):
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
2. (Opcional) Verifica tus credenciales de No-IP antes de crear la infraestructura:
   ```bash
   NOIP_USERNAME="tu_usuario" NOIP_PASSWORD="tu_password" NOIP_HOSTNAME="tu-host.ddns.net" \
     ./scripts/test-noip.sh
   ```
3. Asegúrate de tener tu par de llaves SSH (`aguafix-key.pem` y `aguafix-key.pem.pub`) y tus credenciales de AWS configuradas (`aws configure`).
4. Ejecuta Terraform:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
5. Espera 2–3 minutos mientras `cloud-init` termina el aprovisionamiento y ejecuta la prueba End-to-End:
   ```bash
   ./scripts/verify-e2e.sh http://<tu-hostname-noip>
   ```
6. Al finalizar las pruebas o la grabación del video, destruye todos los recursos limpiamente:
   ```bash
   terraform destroy
   ```

## Diagnóstico en la EC2

Si necesitas revisar el progreso del aprovisionamiento o los contenedores tras conectarte por SSH:

```bash
tail -f /var/log/aguafix-user-data.log
cat /home/ubuntu/aguafix/init.log
cd /home/ubuntu/aguafix && docker compose ps && docker compose logs --tail=50
```

## Reglas de seguridad

- Nunca subir `terraform.tfvars`, `.env`, `*.tfstate*` ni llaves privadas `*.pem` al repositorio.
- No escribir credenciales directamente en archivos `.tf`, `.tftpl` ni scripts.
- Toda creación o eliminación de recursos en AWS debe hacerse únicamente mediante Terraform.
