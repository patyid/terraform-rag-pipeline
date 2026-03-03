# 
# OUTPUTS - Informações de Acesso e Debug
# 

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
    id          = module.ec2.instance_id
    public_ip   = module.ec2.instance_public_ip
    private_ip  = module.ec2.instance_private_ip
    public_dns  = module.ec2.instance_public_dns
    ami_id      = module.ec2.ami_id
    spot_request = module.ec2.spot_instance_request_id
  }
}

output "cloudwatch_logs" {
  description = "Comando para visualizar logs via CloudWatch"
  value       = "aws logs tail /aws/ec2/${var.project_name}-${var.environment} --follow --region ${var.region}"
}

output "debug_commands" {
  description = "Comandos úteis para debugging"
  value = <<-EOT
    
    # Verificar status do user_data
    aws ssm send-command \
      --instance-ids ${module.ec2.instance_id} \
      --document-name AWS-RunShellScript \
      --parameters 'commands=["sudo tail -100 /var/log/user-data.log"]' \
      --region ${var.region}

    # Verificar status do Cloud-init
    aws ssm send-command \
      --instance-ids ${module.ec2.instance_id} \
      --document-name AWS-RunShellScript \
      --parameters 'commands=["sudo cloud-init status --long"]' \
      --region ${var.region}

    # Status do serviço Streamlit
    aws ssm send-command \
      --instance-ids ${module.ec2.instance_id} \
      --document-name AWS-RunShellScript \
      --parameters 'commands=["sudo systemctl status streamlit"]' \
      --region ${var.region}
  EOT
}