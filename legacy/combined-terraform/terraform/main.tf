# 
# MAIN.TF - Orquestrador de Módulos
# RAG Pipeline com GPT-4o mini (SEM Ollama)
# 

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-backend-bucket-452271769418"
    key     = "state/rag-pipeline-project.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "rag-pipeline"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# 
# DATA SOURCES
# 

data "aws_caller_identity" "current" {}

data "aws_kms_alias" "ssm_default" {
  name = "alias/aws/ssm"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = var.allowed_azs
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "vector_db" {
  source = "./modules/s3"
  count  = var.vector_store_bucket_name == "" ? 1 : 0

  bucket_name = format(
    "%s-%s-vector-db",
    var.project_name,
    var.environment
  )

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# 
# GLUE - APP ZIP (rag-pipeline-app)
# 

data "archive_file" "rag_pipeline_app" {
  count = var.enable_glue_ingestion_job && var.glue_build_app_zip ? 1 : 0

  type        = "zip"
  source_dir  = "${path.root}/../rag-pipeline-app"
  output_path = "${path.module}/glue/dist/rag-pipeline-app.zip"

  excludes = [
    "**/.git/**",
    "**/__pycache__/**",
    "**/*.pyc",
    "**/.pytest_cache/**",
    "**/.mypy_cache/**",
    "**/.ruff_cache/**",
    "**/.venv/**",
    "**/venv/**",
    "**/data/**",
    "**/.env",
  ]
}

# 
# GLUE - ASSETS BUCKET (script + artifacts)
# 

resource "aws_s3_bucket" "glue_assets" {
  count = var.enable_glue_ingestion_job && var.glue_assets_bucket_name == "" ? 1 : 0

  bucket = format(
    "%s-%s-%s-glue-assets",
    var.project_name,
    var.environment,
    data.aws_caller_identity.current.account_id
  )

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "glue_assets" {
  count  = length(aws_s3_bucket.glue_assets) > 0 ? 1 : 0
  bucket = aws_s3_bucket.glue_assets[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 
# MÓDULO: IAM Role + SSM + Secrets Access
# 

locals {
  pdf_bucket_arn         = var.pdf_bucket_name != "" ? "arn:aws:s3:::${var.pdf_bucket_name}" : ""
  vector_bucket_arn      = var.vector_store_bucket_name != "" ? "arn:aws:s3:::${var.vector_store_bucket_name}" : try(module.vector_db[0].bucket_arn, "")
  glue_assets_bucket_arn = var.glue_assets_bucket_name != "" ? "arn:aws:s3:::${var.glue_assets_bucket_name}" : try(aws_s3_bucket.glue_assets[0].arn, "")

  s3_bucket_arns_effective = distinct(compact(concat(
    var.s3_bucket_arns,
    [local.pdf_bucket_arn, local.vector_bucket_arn, local.glue_assets_bucket_arn]
  )))

  vector_store_bucket_name_effective = var.vector_store_bucket_name != "" ? var.vector_store_bucket_name : try(module.vector_db[0].bucket_name, "")
  glue_assets_bucket_name_effective  = var.glue_assets_bucket_name != "" ? var.glue_assets_bucket_name : try(aws_s3_bucket.glue_assets[0].bucket, "")

  rag_pipeline_app_requirements_path    = "${path.root}/../rag-pipeline-app/requirements.txt"
  rag_pipeline_app_requirements_content = var.enable_glue_ingestion_job ? file(local.rag_pipeline_app_requirements_path) : ""
  rag_pipeline_app_additional_python_modules = join(",", [
    for line in split("\n", local.rag_pipeline_app_requirements_content) :
    trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ])
  glue_additional_python_modules = var.glue_additional_python_modules_override != "" ? var.glue_additional_python_modules_override : local.rag_pipeline_app_additional_python_modules
}

module "iam" {
  source = "./modules/iam-ssm"

  name_prefix = "${var.project_name}-${var.environment}"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  # Acesso a Parameter Store para configurações
  parameter_arns = [
    "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
  ]

  # Acesso a S3 para documentos RAG
  s3_access_enabled = var.enable_s3_access
  s3_bucket_arns    = local.s3_bucket_arns_effective
  s3_actions = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:ListBucket",
    "s3:DeleteObject"
  ]

  tags = {
    Environment = var.environment
    CostCenter  = "data-engineering"
  }
}

# 
# MÓDULO: Security Group
# 

module "security_group" {
  source = "./modules/security-group"

  name_prefix = "${var.project_name}-${var.environment}"
  vpc_id      = data.aws_vpc.default.id
  description = "Security Group para RAG Pipeline Streamlit"

  # Regra de ingress para Streamlit (porta 8501)
  ingress_rules = var.app_runtime == "streamlit" ? [
    {
      from_port   = var.app_port
      to_port     = var.app_port
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
      description = "Streamlit app access from authorized IP"
    }
  ] : []

  # Egress padrão: permitir todo tráfego de saída
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  openai_api_key                = var.openai_api_key
  openai_api_key_parameter_name = var.openai_api_key_parameter_name

  tags = {
    Environment = var.environment
  }
}

# 
# MÓDULO: EC2 Spot Instance
# 
locals {
  subnet_id = data.aws_subnets.available.ids[0]

  user_data_rendered = templatefile("${path.module}/user_data.sh", {
    app_git_repo                  = var.app_git_repo
    app_git_branch                = var.app_git_branch
    app_dir_name                  = var.app_dir_name
    app_entry_point               = var.app_entry_point
    app_runtime                   = var.app_runtime
    app_args                      = var.app_args
    app_autostart                 = var.app_autostart
    app_port                      = var.app_port
    aws_region                    = var.region
    openai_api_key_parameter_name = var.openai_api_key_parameter_name
    pdf_bucket_name               = var.pdf_bucket_name
    vector_store_bucket_name      = local.vector_store_bucket_name_effective
    data_path                     = "/mnt/data" # não usado, mas mantido para compatibilidade
    fallback_path                 = "/var/lib/app-data"
  })
}

module "ec2" {
  source = "./modules/ec2-spot"

  name_prefix = "${var.project_name}-${var.environment}"

  # Tipo de Instância (AMI selecionada internamente no módulo via vars)
  instance_type = var.instance_type

  # Rede
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [module.security_group.security_group_id]

  # IAM
  iam_instance_profile = module.iam.instance_profile_name

  # Spot Options
  spot_instance_type    = "one-time"
  interruption_behavior = "terminate"
  spot_max_price        = var.spot_max_price

  # Storage
  root_volume_size       = var.root_volume_size
  root_volume_type       = "gp3"
  root_volume_encrypted  = true
  root_volume_iops       = 3000
  root_volume_throughput = 125

  # User Data
  user_data                   = local.user_data_rendered
  user_data_replace_on_change = true

  # Segurança
  require_imdsv2 = true

  # Monitoramento
  detailed_monitoring = var.enable_detailed_monitoring

  tags = {
    Environment = var.environment
    App         = "streamlit-rag"
    Backup      = "false"
  }
}



# 
# GLUE JOB - ingestão (rag-pipeline-app)
# 

resource "aws_s3_object" "glue_job_script" {
  count = var.enable_glue_ingestion_job ? 1 : 0

  bucket       = local.glue_assets_bucket_name_effective
  key          = var.glue_script_s3_key
  source       = "${path.module}/glue/rag_pipeline_job.py"
  content_type = "text/x-python"
  etag         = filemd5("${path.module}/glue/rag_pipeline_job.py")
}

resource "aws_s3_object" "rag_pipeline_app_zip" {
  count = var.enable_glue_ingestion_job ? 1 : 0

  bucket = local.glue_assets_bucket_name_effective
  key    = var.glue_artifact_s3_key
  source = var.glue_build_app_zip ? data.archive_file.rag_pipeline_app[0].output_path : "${path.root}/glue/dist/rag-pipeline-app.zip"

  etag = var.glue_build_app_zip ? data.archive_file.rag_pipeline_app[0].output_md5 : null
}

resource "aws_iam_role" "glue_ingestion" {
  count = var.enable_glue_ingestion_job ? 1 : 0

  name = "${var.project_name}-${var.environment}-glue-ingestion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  count = var.enable_glue_ingestion_job ? 1 : 0

  role       = aws_iam_role.glue_ingestion[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_ingestion_inline" {
  count = var.enable_glue_ingestion_job ? 1 : 0

  name = "${var.project_name}-${var.environment}-glue-ingestion-inline"
  role = aws_iam_role.glue_ingestion[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.openai_api_key_parameter_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          data.aws_kms_alias.ssm_default.target_key_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = compact([
          local.pdf_bucket_arn,
          local.pdf_bucket_arn != "" ? "${local.pdf_bucket_arn}/*" : "",
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = compact([
          local.vector_bucket_arn,
          local.vector_bucket_arn != "" ? "${local.vector_bucket_arn}/*" : "",
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = compact([
          local.glue_assets_bucket_arn,
          local.glue_assets_bucket_arn != "" ? "${local.glue_assets_bucket_arn}/*" : "",
        ])
      }
    ]
  })
}

resource "aws_glue_job" "rag_pipeline_ingestion" {
  count = var.enable_glue_ingestion_job ? 1 : 0

  name              = "${var.project_name}-${var.environment}-rag-pipeline-ingestion"
  role_arn          = aws_iam_role.glue_ingestion[0].arn
  glue_version      = var.glue_version
  number_of_workers = var.glue_number_of_workers
  worker_type       = var.glue_worker_type
  timeout           = var.glue_timeout_minutes
  max_retries       = var.glue_max_retries

  execution_property {
    max_concurrent_runs = 1
  }

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${local.glue_assets_bucket_name_effective}/${var.glue_script_s3_key}"
  }

  default_arguments = {
    "--job-language"              = "python"
    "--TempDir"                   = "s3://${local.glue_assets_bucket_name_effective}/glue/temp/"
    "--additional-python-modules" = local.glue_additional_python_modules
    "--extra-py-files"            = "s3://${local.glue_assets_bucket_name_effective}/${var.glue_artifact_s3_key}"
    "--db-name"                   = var.glue_vector_db_name
    "--data-dir"                  = var.glue_pdf_prefix
    "--pdf-bucket"                = var.pdf_bucket_name
    "--vector-bucket"             = local.vector_store_bucket_name_effective
  }

  depends_on = [
    aws_s3_object.glue_job_script,
    aws_s3_object.rag_pipeline_app_zip,
    aws_iam_role_policy_attachment.glue_service_role,
    aws_iam_role_policy.glue_ingestion_inline,
  ]
}
