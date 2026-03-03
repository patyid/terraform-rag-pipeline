# 
# VARIABLES - Configurações do Projeto
# 

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nome do projeto para naming de recursos"
  type        = string
  default     = "rag-pipeline"
}

# 
# NETWORK
# 

variable "allowed_azs" {
  description = "Availability Zones permitidas"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
}

variable "allowed_cidr" {
  description = "CIDR autorizado para acesso ao Streamlit (seu IP/32 recomendado)"
  type        = string
}

# 
# COMPUTE
# 

variable "instance_type" {
  description = "Tipo da instância EC2 (CPU-only suficiente para GPT-4o mini)"
  type        = string
  default     = "t3.xlarge"
}

variable "spot_max_price" {
  description = "Preço máximo para Spot (null = preço on-demand)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Tamanho do volume raiz em GB"
  type        = number
  default     = 30
}

# 
# APLICAÇÃO
# 

variable "app_git_repo" {
  description = "URL do repositório Git da aplicação"
  type        = string
  default     = "https://github.com/patyid/chatbot-project.git"
}

variable "app_git_branch" {
  description = "Branch do repositório"
  type        = string
  default     = "main"
}

variable "app_dir_name" {
  description = "Nome do diretório da aplicação dentro do repo"
  type        = string
  default     = "chatbot-app"
}

variable "app_entry_point" {
  description = "Arquivo de entrada do Streamlit"
  type        = string
  default     = "chat_stream.py"
}

variable "app_port" {
  description = "Porta da aplicação Streamlit"
  type        = number
  default     = 8501
}

# 
# FEATURE FLAGS
# 

variable "enable_s3_access" {
  description = "Habilitar acesso a S3 para documentos RAG"
  type        = bool
  default     = true
}

variable "s3_bucket_arns" {
  description = "ARNs dos buckets S3 permitidos"
  type        = list(string)
  default     = []
}

variable "enable_detailed_monitoring" {
  description = "Habilitar monitoramento detalhado do CloudWatch"
  type        = bool
  default     = false
}

variable "create_cloudwatch_log_group" {
  description = "Criar Log Group do CloudWatch"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs"
  type        = number
  default     = 7
}

variable "create_ssm_parameters" {
  description = "Criar parâmetros no SSM Parameter Store"
  type        = bool
  default     = true
}

variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
  sensitive   = true
}