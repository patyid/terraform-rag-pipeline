# 
# OUTPUTS: EC2 Spot Instance
# 

output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN da instância EC2"
  value       = aws_instance.this.arn
}

output "instance_public_ip" {
  description = "IP público da instância"
  value       = aws_instance.this.public_ip
}

output "instance_public_dns" {
  description = "DNS público da instância"
  value       = aws_instance.this.public_dns
}

output "instance_private_ip" {
  description = "IP privado da instância"
  value       = aws_instance.this.private_ip
}

output "instance_private_dns" {
  description = "DNS privado da instância"
  value       = aws_instance.this.private_dns
}

output "ami_id" {
  description = "ID da AMI utilizada"
  value       = data.aws_ami.this.id
}

output "spot_instance_request_id" {
  description = "ID da requisição Spot"
  value       = aws_instance.this.spot_instance_request_id
}

output "ssm_start_session_command" {
  description = "Comando para iniciar sessão SSM"
  value       = "aws ssm start-session --target ${aws_instance.this.id}"
}