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

variable "allowed_azs" {
  description = "Availability Zones permitidas"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
}

variable "allowed_cidr" {
  description = "CIDRs autorizados para acesso ao Streamlit (seu IP/32 recomendado)"
  type        = list(string)

  validation {
    condition     = var.app_runtime != "streamlit" || length(var.allowed_cidr) > 0
    error_message = "allowed_cidr deve ter pelo menos 1 CIDR quando app_runtime = \"streamlit\"."
  }
}

variable "instance_type" {
  description = "Tipo da instância EC2"
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

variable "app_entry_point" {
  description = "Arquivo de entrada do Streamlit"
  type        = string
  default     = "streamlit_app.py"
}

variable "app_s3_bucket" {
  description = "Bucket S3 opcional com o streamlit_app.py"
  type        = string
  default     = "script-452271769418"
}

variable "app_s3_key" {
  description = "Chave S3 opcional do streamlit_app.py"
  type        = string
  default     = "streamlit/streamlit_app.py"
}

variable "app_runtime" {
  description = "Runtime do app: streamlit (web) ou python (job/script)"
  type        = string
  default     = "streamlit"

  validation {
    condition     = contains(["streamlit", "python"], var.app_runtime)
    error_message = "app_runtime deve ser \"streamlit\" ou \"python\"."
  }
}

variable "app_args" {
  description = "Argumentos extras (separados por espaço) passados para o entrypoint"
  type        = string
  default     = ""
}

variable "app_autostart" {
  description = "Iniciar o serviço automaticamente no boot"
  type        = bool
  default     = true
}

variable "app_port" {
  description = "Porta da aplicação Streamlit"
  type        = number
  default     = 8501
}

variable "enable_s3_access" {
  description = "Habilitar acesso a S3 para documentos RAG"
  type        = bool
  default     = true
}

variable "pdf_bucket_name" {
  description = "Nome do bucket S3 onde ficam os PDFs (opcional; usado para permissões IAM)"
  type        = string
  default     = ""
}

variable "vector_store_bucket_name" {
  description = "Nome do bucket S3 onde ficam os vector stores (opcional; se vazio, Terraform cria um bucket gerenciado)"
  type        = string
  default     = ""
}

variable "vector_db_name" {
  description = "Nome do vector DB (prefixo de diretório no S3)"
  type        = string
  default     = "vector_db"
}

variable "vector_store_prefix" {
  description = "Prefixo no S3 onde ficam os vector stores"
  type        = string
  default     = "vector-stores/"
}

variable "embedding_model" {
  description = "Modelo de embeddings (deve ser o mesmo usado na ingestão)"
  type        = string
  default     = "text-embedding-3-small"
}

variable "chat_model" {
  description = "Modelo de chat usado pelo app"
  type        = string
  default     = "gpt-4o-mini"
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

variable "openai_api_key_parameter_name" {
  description = "Nome do parâmetro (SecureString) no SSM Parameter Store para a OpenAI API Key"
  type        = string
  default     = "/rag-pipeline/openai-api-key"
}

variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
  sensitive   = true
  default     = ""
}
