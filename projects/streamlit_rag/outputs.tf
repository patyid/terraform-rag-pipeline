output "application_url" {
  description = "URL de acesso ao Streamlit"
  value       = "http://${module.ec2.instance_public_ip}:${var.app_port}"
}

output "ssm_start_session" {
  description = "Comando para acessar a instância via SSM"
  value       = "aws ssm start-session --target ${module.ec2.instance_id} --region ${var.region}"
}

output "instance_details" {
  description = "Detalhes da instância EC2"
  value = {
    id           = module.ec2.instance_id
    public_ip    = module.ec2.instance_public_ip
    private_ip   = module.ec2.instance_private_ip
    public_dns   = module.ec2.instance_public_dns
    ami_id       = module.ec2.ami_id
    spot_request = module.ec2.spot_instance_request_id
  }
}

output "cloudwatch_logs" {
  description = "Comando para visualizar logs via CloudWatch"
  value       = "aws logs tail /aws/ec2/${var.project_name}-${var.environment} --follow --region ${var.region}"
}

