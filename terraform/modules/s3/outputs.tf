output "bucket_name" {
  description = "Nome do bucket usado como vector DB"
  value       = aws_s3_bucket.vector_db.bucket
}

output "bucket_id" {
  description = "ID do bucket vector DB"
  value       = aws_s3_bucket.vector_db.id
}

output "bucket_arn" {
  description = "ARN do bucket vector DB"
  value       = aws_s3_bucket.vector_db.arn
}
