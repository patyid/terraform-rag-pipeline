# 
# OUTPUTS: IAM Role para SSM
# 

output "role_name" {
  description = "Nome da IAM Role"
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "ARN da IAM Role"
  value       = aws_iam_role.this.arn
}

output "role_id" {
  description = "ID da IAM Role"
  value       = aws_iam_role.this.id
}

output "instance_profile_name" {
  description = "Nome do Instance Profile"
  value       = aws_iam_instance_profile.this.name
}

output "instance_profile_arn" {
  description = "ARN do Instance Profile"
  value       = aws_iam_instance_profile.this.arn
}

output "instance_profile_id" {
  description = "ID do Instance Profile"
  value       = aws_iam_instance_profile.this.id
}