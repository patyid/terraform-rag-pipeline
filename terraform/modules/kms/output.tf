output "key_id" {
  description = "ID da KMS"
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "ARN da KMS"
  value       = aws_kms_key.this.arn
}

output "alias_name" {
  description = "Alias da KMS"
  value       = aws_kms_alias.this.name
}