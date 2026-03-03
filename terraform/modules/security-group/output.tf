# 
# OUTPUTS: Security Group
# 

output "security_group_id" {
  description = "ID do Security Group"
  value       = aws_security_group.this.id
}

output "security_group_arn" {
  description = "ARN do Security Group"
  value       = aws_security_group.this.arn
}

output "security_group_name" {
  description = "Nome do Security Group"
  value       = aws_security_group.this.name
}

output "security_group_vpc_id" {
  description = "ID da VPC do Security Group"
  value       = aws_security_group.this.vpc_id
}

output "security_group_owner_id" {
  description = "ID do owner do Security Group"
  value       = aws_security_group.this.owner_id
}