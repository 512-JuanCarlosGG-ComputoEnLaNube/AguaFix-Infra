# Guía Paso a Paso — Persona 3 (No-IP + `user_data` + Integración End-to-End)

La infraestructura base en Terraform (**Persona 2**) y los ajustes de la API + GitHub Actions (**Persona 1**) ya están listos y probados.

Este documento explica exactamente qué te falta hacer como **Persona 3** para completar el aprovisionamiento automático y las pruebas finales.

---

## Acuerdos ya configurados (NO cambiar)
- **Sistema operativo / Usuario SSH**: Ubuntu 24.04 (`ubuntu`)
- **Ruta del compose en la EC2**: `/home/ubuntu/aguafix` (ya configurada en `AguaFix/.github/workflows/docker-publish.yml`)
- **Imagen Docker de la API**: `deborahvp/aguafix-api:latest` (puerto `80:3000`)

---

## Paso 1: Crear cuenta y hostname en No-IP
1. Crea una cuenta en [noip.com](https://www.noip.com/) y registra un hostname gratuito (ej. `aguafix-equipo.ddns.net`).
2. Obtén tus credenciales de actualización dinámica (**Username/Password** o **DDNS Key**).
3. Prueba manualmente que la actualización dinámica responde (`good` o `nochg`):
   ```bash
   curl -u "<NOIP_USER>:<NOIP_PASS>" "https://dynupdate.no-ip.com/nic/update?hostname=<TU_HOSTNAME>&myip=<CUALQUIER_IP>"
   ```

---

## Paso 2: Completar `user_data.sh.tftpl` en este repositorio
Reemplaza el placeholder actual en `user_data.sh.tftpl` por el script real de aprovisionamiento.

### Variables que `ec2.tf` YA inyecta automáticamente en `user_data.sh.tftpl`
No necesitas tocar `ec2.tf` ni `variables.tf` — puedes usar directamente estas variables con `${nombre}`:

| Categoría | Variables disponibles |
|---|---|
| **Rutas / Docker** | `${compose_dir}`, `${docker_image}` |
| **No-IP** | `${noip_hostname}`, `${noip_username}`, `${noip_password}` |
| **Base de datos** | `${db_name}`, `${db_user}`, `${db_password}` |
| **Correo SMTP** | `${mail_host}`, `${mail_port}`, `${mail_user}`, `${mail_password}`, `${mail_from}`, `${maintenance_email}` |
| **Seguridad / AWS S3** | `${jwt_secret}`, `${aws_region}`, `${aws_s3_bucket}`, `${aws_access_key_id}`, `${aws_secret_access_key}` |

### Qué debe hacer `user_data.sh.tftpl` al iniciar la EC2
1. **Instalar Docker y Docker Compose** (plugin `docker-compose-plugin` en Ubuntu) y agregar el usuario `ubuntu` al grupo `docker` (`usermod -aG docker ubuntu`) para que GitHub Actions pueda ejecutar `docker compose` sin `sudo`.
2. **Obtener la IP pública de la EC2** (usando IMDSv2):
   ```bash
   TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
   PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
   ```
3. **Actualizar No-IP** con `curl` usando `${noip_username}`, `${noip_password}`, `${noip_hostname}` y `$PUBLIC_IP`.
4. **Generar `${compose_dir}/.env`** con todas las variables de BD, SMTP, JWT y AWS S3 (`AWS_S3_BUCKET=${aws_s3_bucket}`, `PORT=80`, `NODE_ENV=production`, etc.).
5. **Generar `${compose_dir}/compose.yaml`** con:
   - Servicio `postgres` (`postgres:16-alpine` con volumen persistente y healthcheck).
   - Servicio `api` (`${docker_image}`, `env_file: [.env]`, `DB_HOST: postgres`, `ports: ["80:3000"]`, `depends_on: postgres (service_healthy)`).
6. **Ajustar permisos y levantar contenedores**:
   ```bash
   chown -R ubuntu:ubuntu "${compose_dir}"
   cd "${compose_dir}"
   docker compose up -d
   ```

> **Tip de Terraform:** dentro de `user_data.sh.tftpl`, si usas variables de Bash como `$PUBLIC_IP`, escríbelas sin llaves (`$PUBLIC_IP`) o escápalas como `$${VARIABLE}` para que Terraform no intente interpretarlas.

---

## Paso 3: Levantar la infraestructura con Terraform
1. Clona este repositorio (`AguaFix-Infra`) y copia `terraform.tfvars.example` a `terraform.tfvars`.
2. Rellena `terraform.tfvars` con los valores reales (incluyendo tus credenciales de No-IP, el nombre único del bucket S3, BD, SMTP, JWT y AWS).
3. Asegúrate de tener tu llave SSH generada (`aguafix-key.pem` y `aguafix-key.pem.pub`) y tus credenciales de AWS configuradas (`aws configure`).
4. Ejecuta:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
5. Guarda los outputs que imprime Terraform (`ec2_public_ip`, `app_url`, `ssh_command`).

---

## Paso 4: Configurar GitHub Secrets en el repo de la API (`AguaFix`)
En el repositorio **AguaFix** (API) → **Settings → Secrets and variables → Actions**, registra/actualiza:
- `EC2_HOST`: la IP pública (`ec2_public_ip`) o tu dominio de No-IP (`<hostname-noip>`).
- `EC2_SSH_KEY`: el contenido completo de la llave privada `aguafix-key.pem` (incluyendo `-----BEGIN ...-----` y `-----END ...-----`).

*(Asegúrate de que `DOCKER_USER` y `DOCKER_PASSWORD` también sigan configurados).*

---

## Paso 5: Pruebas End-to-End (Checklist final)
Valida cada punto antes de grabar el video / entregar:

- [ ] **No-IP + Salud de la API**: `curl http://<hostname-noip>/` (o `/api/health`) responde correctamente.
- [ ] **Registro y Login**: Crear usuario e iniciar sesión (recibiendo JWT).
- [ ] **Creación de reporte con imagen en S3**: Subir un reporte con foto y verificar que la URL de S3 devuelta abre la imagen públicamente en el navegador.
- [ ] **Correo recibido**: Confirmar que llegó el correo de notificación a `MAINTENANCE_EMAIL`.
- [ ] **Auto-despliegue CI/CD**: Hacer un cambio pequeño en la API, hacer `git push` a `main`, verificar que **GitHub Actions** termine en verde y que el cambio se refleje automáticamente en `http://<hostname-noip>/`.
- [ ] **Destrucción limpia**: Al terminar las pruebas/video, ejecutar `terraform destroy` y verificar que todos los recursos (incluyendo el bucket S3 con imágenes) se eliminen sin errores.

---

## Reglas de seguridad (Recordatorio)
- ❌ **Nunca** subir `.env`, `terraform.tfvars`, `*.tfstate*` ni llaves `*.pem` a GitHub.
- ❌ **Nunca** escribir contraseñas o credenciales directamente en `user_data.sh.tftpl` ni en archivos `.tf`.
- ❌ **No** modificar recursos a mano en la consola de AWS.
