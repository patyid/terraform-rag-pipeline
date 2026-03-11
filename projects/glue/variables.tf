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

variable "pdf_bucket_name" {
  description = "Bucket S3 onde ficam os PDFs (obrigatório para o Glue job)"
  type        = string
}

variable "vector_store_bucket_name" {
  description = "Bucket S3 onde ficam os vector stores (se vazio, Terraform cria um bucket gerenciado)"
  type        = string
  default     = ""
}

variable "openai_api_key_parameter_name" {
  description = "Nome do parâmetro (SecureString) no SSM Parameter Store para a OpenAI API Key"
  type        = string
  default     = "/rag-pipeline/openai-api-key"
}

variable "rag_pipeline_app_dir" {
  description = "Diretório (relativo a projects/glue) com o código do rag-pipeline-app"
  type        = string
  default     = "rag-pipeline-app"
}

variable "glue_assets_bucket_name" {
  description = "Bucket S3 para armazenar script/artefatos do Glue (se vazio, Terraform cria um)"
  type        = string
  default     = ""
}

variable "glue_build_app_zip" {
  description = "Gerar automaticamente um zip do `rag-pipeline-app`"
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
  default     = "5.0"
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
  description = "Override do --additional-python-modules (CSV). Se vazio, deriva do requirements.txt do app."
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
