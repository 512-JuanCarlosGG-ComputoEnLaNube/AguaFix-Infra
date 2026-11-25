# Guía Manual Paso a Paso — Persona 2 (AguaFix-Infra)

Esta carpeta ya tiene todos los archivos base de Terraform creados según `reparticion-roles-aguafix.pdf`.
Aquí tienes exactamente lo que **te falta hacer manualmente** desde tu terminal.

---

## Paso 1: Instalar Terraform y AWS CLI

En tu sistema (Arch Linux / Omarchy), instala ambas herramientas:

```bash
sudo pacman -S terraform aws-cli-v2
```

Verifica que quedaron instaladas:

```bash
terraform -version
aws --version
```

---

## Paso 2: Configurar tus credenciales de AWS en tu terminal

Terraform necesita permiso para crear recursos en tu cuenta de AWS. **Nunca** pongas estas credenciales dentro de los archivos `.tf`.

### Opción A: Cuenta normal de AWS (IAM User)
Ejecuta:
```bash
aws configure
```
Te pedirá:
- **AWS Access Key ID**: tu access key
- **AWS Secret Access Key**: tu secret key
- **Default region name**: `us-east-1`
- **Default output format**: `json`

### Opción B: AWS Academy / Learner Lab (credenciales temporales)
Si usas AWS Academy, copia las 3 variables desde **AWS Details -> AWS CLI -> Show** y pégalas en tu terminal antes de correr Terraform:
```bash
export AWS_ACCESS_KEY_ID="tu_access_key"
export AWS_SECRET_ACCESS_KEY="tu_secret_key"
export AWS_SESSION_TOKEN="tu_session_token"
```
*(Recuerda que en AWS Academy el token expira cada ~4 horas y debes volver a exportarlo).*

Prueba que tu sesión funciona:
```bash
aws sts get-caller-identity
```
Si te devuelve tu `Account` y `Arn`, ya estás conectado a AWS.

---

## Paso 3: Generar tu par de llaves SSH

Entra a esta carpeta y genera las llaves (puedes presionar Enter cuando te pida passphrase para dejarla vacía):

```bash
cd /home/cgg/Dev/university/desarrollo-nube/AguaFix-Infra
ssh-keygen -t rsa -b 4096 -f ./aguafix-key.pem -N ""
chmod 400 ./aguafix-key.pem
```

Esto creará dos archivos:
- `aguafix-key.pem` → **Llave privada** (ya está ignorada en `.gitignore`, **NUNCA** la subas a GitHub).
- `aguafix-key.pem.pub` → **Llave pública** (es la que lee `ec2.tf` para crear `aws_key_pair`).

> **Nota para Persona 3:** cuando integren GitHub Actions, deberán copiar el contenido de `aguafix-key.pem` en el secret `EC2_SSH_KEY` de GitHub (nunca en el repositorio).

---

## Paso 4: Crear tu archivo `terraform.tfvars` local

Copia el archivo de ejemplo:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Abre `terraform.tfvars` y rellena los valores reales:
1. **`s3_bucket_name`**: pon un nombre único en todo AWS, en minúsculas y con guiones (ej. `aguafix-imagenes-equipo3-2026`).
2. **`instance_type`**: deja `t3.micro` (o cámbialo a `t2.micro` si tu cuenta solo permite `t2.micro`).
3. **`noip_hostname`**, **`noip_username`**, **`noip_password`**: pídelos a Persona 3 (para probar tú solo al inicio puedes dejar valores de prueba).
4. **BD, Correo, JWT y credenciales AWS**: usa los mismos valores del `.env` del proyecto `AguaFix`.

> `terraform.tfvars` ya está protegido en `.gitignore`, así que Git no lo subirá.

---

## Paso 5: Probar Terraform (init -> validate -> plan -> apply)

Ejecuta estos comandos en orden dentro de `/home/cgg/Dev/university/desarrollo-nube/AguaFix-Infra`:

```bash
# 1. Descarga el provider de AWS (solo la primera vez)
terraform init

# 2. Formatea y valida que no haya errores de sintaxis
terraform fmt
terraform validate

# 3. Previsualiza exactamente qué va a crear en AWS (no crea nada todavía)
terraform plan

# 4. Crea la infraestructura real en AWS (escribe "yes" cuando te pregunte)
terraform apply
```

Al terminar `terraform apply`, verás los **Outputs**:
- `ec2_public_ip`
- `app_url`
- `ssh_command`
- `s3_bucket_name`
- `s3_bucket_base_url`

---

## Paso 6: Verificar que todo funciona

1. **Probar conexión SSH** (espera ~30 segundos a que arranque Ubuntu y ejecuta el comando que salió en `ssh_command`):
   ```bash
   ssh -i aguafix-key.pem ubuntu@<IP_PUBLICA_DEL_OUTPUT>
   ```
   Una vez dentro, verifica que el placeholder corrió:
   ```bash
   cat /home/ubuntu/aguafix/init.log
   exit
   ```

2. **Probar el Bucket S3** (opcional):
   - Sube un archivo de prueba desde tu compu con `aws s3 cp` o revisa en la consola de AWS (solo lectura, no modifiques nada a mano) que el bucket existe y tiene la política `PublicReadGetObject`.

3. **Destruir al terminar tus pruebas** (para no gastar créditos y confirmar que `force_destroy = true` funciona limpio):
   ```bash
   terraform destroy
   ```
   Escribe `yes` y verifica que todos los recursos se eliminen sin errores.

---

## Paso 7: Subir el repositorio a GitHub (con revisión de seguridad)

1. Inicializa Git en esta carpeta:
   ```bash
   git init
   git branch -M main
   ```

2. **MUY IMPORTANTE — Verifica qué archivos se van a subir antes del commit:**
   ```bash
   git status
   ```
   Asegúrate de que **NO aparezcan** en la lista:
   - `terraform.tfvars`
   - `*.tfstate` / `*.tfstate.backup`
   - `.terraform/`
   - `aguafix-key.pem`

   *(Si ves `aguafix-key.pem.pub`, decide si prefieres no subirla tampoco agregando `*.pub` al `.gitignore`, aunque es pública).*

3. Haz el commit y súbelo al nuevo repositorio de GitHub:
   ```bash
   git add .
   git commit -m "feat: infraestructura base AWS con Terraform (EC2, SG, KeyPair, S3)"
   git remote add origin <URL_DE_TU_NUEVO_REPO_GITHUB>
   git push -u origin main
   ```

---

## Paso 8: Coordinación con Persona 3

Cuando subas el repo, compártele el enlace a **Persona 3** y dile:
1. Que la EC2 usa **Ubuntu 24.04** (usuario `ubuntu`) y la ruta del compose es **`/home/ubuntu/aguafix`** (igual que lo configuró Persona 1 en GitHub Actions).
2. Que solo tiene que reemplazar el contenido de `user_data.sh.tftpl` usando las variables que ya están inyectadas en `ec2.tf`:
   - `compose_dir`, `docker_image`
   - `noip_hostname`, `noip_username`, `noip_password`
   - `db_name`, `db_user`, `db_password`
   - `mail_host`, `mail_port`, `mail_user`, `mail_password`, `mail_from`, `maintenance_email`
   - `jwt_secret`, `aws_region`, `aws_s3_bucket`, `aws_access_key_id`, `aws_secret_access_key`
