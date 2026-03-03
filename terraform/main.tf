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

# MÓDULO: KMS Key
# 

module "kms" {
  source = "./modules/kms"

  alias_name = "${var.project_name}-${var.environment}-key"

  allowed_role_arns = [
    format(
      "arn:aws:iam::%s:role/%s",
      data.aws_caller_identity.current.account_id,
      "${var.project_name}-${var.environment}-ssm-role"
    )
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# 
# MÓDULO: IAM Role + SSM + Secrets Access
# 

module "iam" {
  source = "./modules/iam-ssm"

  name_prefix = "${var.project_name}-${var.environment}"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  # Acesso a Secrets Manager para API keys (OpenAI, etc.)
  secrets_access_enabled = true
  secret_arns = [
    "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
  ]

  # Acesso a Parameter Store para configurações
  parameter_arns = [
    "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
  ]

  # Acesso a S3 para documentos RAG
  s3_access_enabled = var.enable_s3_access
  s3_bucket_arns    = var.s3_bucket_arns
  s3_actions = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:ListBucket",
    "s3:DeleteObject"
  ]

  kms_key_arns = [module.kms.key_arn]

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
  ingress_rules = [
    {
      from_port   = var.app_port
      to_port     = var.app_port
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
      description = "Streamlit app access from authorized IP"
    }
  ]

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

  kms_key_id = module.kms.key_id

  openai_api_key = var.openai_api_key

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
    app_git_repo    = var.app_git_repo
    app_git_branch  = var.app_git_branch
    app_dir_name    = var.app_dir_name
    app_entry_point = var.app_entry_point
    app_port        = var.app_port
    data_path       = "/mnt/data" # não usado, mas mantido para compatibilidade
    fallback_path   = "/var/lib/app-data"
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
