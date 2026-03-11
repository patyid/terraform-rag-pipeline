resource "aws_s3_bucket" "vector_db" {
  bucket = var.bucket_name

  tags = merge(
    {
      Name = var.bucket_name
    },
    var.tags
  )
}

# Bloquear acesso público
resource "aws_s3_bucket_public_access_block" "vector_db" {
  bucket = aws_s3_bucket.vector_db.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Pasta/prefixo para organizar os vector stores
resource "aws_s3_object" "vector_prefix" {
  bucket       = aws_s3_bucket.vector_db.id
  key          = "vector-stores/"
  content_type = "application/x-directory"
}
