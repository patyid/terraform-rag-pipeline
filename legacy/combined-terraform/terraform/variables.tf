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

  validation {
    condition     = var.app_runtime != "streamlit" || var.allowed_cidr != ""
    error_message = "allowed_cidr é obrigatório quando app_runtime = \"streamlit\"."
  }
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

variable "vector_git_repo" {
  description = "URL do repositório Git para o app/job de vetores (rag-pipeline-app)"
  type        = string
  default     = "https://github.com/patyid/rag-pipeline-app.git"
}

variable "app_git_branch_vector" {
  description = "Branch do repositório de vetores (rag-pipeline-app)"
  type        = string
  default     = "main"
}

variable "vector_dir_name" {
  description = "Nome do diretório do app/job de vetores dentro de /opt/app"
  type        = string
  default     = "rag-pipeline-app"
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
  description = "Iniciar o serviço automaticamente no boot (recomendado: true para streamlit, false para jobs)"
  type        = bool
  default     = true
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

# 
# GLUE (INGESTÃO)
# 

variable "enable_glue_ingestion_job" {
  description = "Habilitar AWS Glue Job para ingestão (rag-pipeline-app)"
  type        = bool
  default     = true
}

variable "glue_assets_bucket_name" {
  description = "Bucket S3 para armazenar script/artefatos do Glue (se vazio, Terraform cria um)"
  type        = string
  default     = ""
}

variable "glue_build_app_zip" {
  description = "Gerar automaticamente um zip do `rag-pipeline-app` via `git archive` (requer o repo clonado localmente)"
  type        = bool
  default     = true
}

variable "glue_worker_type" {
  description = "Tipo de worker do Glue (ex: G.1X)"
  type        = string
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Número de workers do Glue (máximo 10)"
  type        = number
  default     = 2

  validation {
    condition     = var.glue_number_of_workers >= 2 && var.glue_number_of_workers <= 10
    error_message = "glue_number_of_workers deve estar entre 2 e 10."
  }
}

variable "glue_timeout_minutes" {
  description = "Timeout do Glue Job (minutos)"
  type        = number
  default     = 60
}

variable "glue_max_retries" {
  description = "Máximo de retries do Glue Job"
  type        = number
  default     = 0
}

variable "glue_version" {
  description = "Versão do AWS Glue (ex: 4.0)"
  type        = string
  default     = "4.0"
}

variable "glue_script_s3_key" {
  description = "Chave S3 do script do Glue"
  type        = string
  default     = "glue/scripts/rag_pipeline_job.py"
}

variable "glue_artifact_s3_key" {
  description = "Chave S3 do zip do app (rag-pipeline-app)"
  type        = string
  default     = "glue/artifacts/rag-pipeline-app.zip"
}

variable "glue_additional_python_modules_override" {
  description = "Override do --additional-python-modules (CSV). Se vazio, deriva de `../rag-pipeline-app/requirements.txt`."
  type        = string
  default     = ""
}

variable "glue_pdf_prefix" {
  description = "Prefixo (dentro do bucket) onde ficam os PDFs"
  type        = string
  default     = "data/raw/"
}

variable "glue_vector_db_name" {
  description = "Nome do vector DB (prefixo de diretório no S3)"
  type        = string
  default     = "vector_db"
}
