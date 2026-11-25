# ==============================================================================
# Bucket S3 para almacenar las imágenes de los reportes
# ==============================================================================

resource "aws_s3_bucket" "images" {
  bucket        = var.s3_bucket_name
  force_destroy = true # Permite que terraform destroy borre el bucket aunque tenga archivos

  tags = {
    Name = "${var.project_name}-images-bucket"
  }
}

# Desactiva el bloqueo de políticas públicas para permitir lectura (s3:GetObject)
resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Política de lectura pública para que las URLs directas de S3 sean visibles desde el Frontend
resource "aws_s3_bucket_policy" "images_public_read" {
  bucket = aws_s3_bucket.images.id

  depends_on = [aws_s3_bucket_public_access_block.images]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })
}
