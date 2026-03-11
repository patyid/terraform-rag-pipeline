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
    key     = "state/rag-pipeline-streamlit.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
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

module "vector_db" {
  source = "../../terraform/modules/s3"
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
# MÓDULO: IAM Role + SSM + Secrets Access
# 

locals {
  pdf_bucket_arn                     = var.pdf_bucket_name != "" ? "arn:aws:s3:::${var.pdf_bucket_name}" : ""
  vector_store_bucket_name_effective = var.vector_store_bucket_name != "" ? var.vector_store_bucket_name : try(module.vector_db[0].bucket_name, "")
  vector_bucket_arn                  = local.vector_store_bucket_name_effective != "" ? "arn:aws:s3:::${local.vector_store_bucket_name_effective}" : ""

  s3_bucket_arns_effective = distinct(compact(concat(
    var.s3_bucket_arns,
    [local.pdf_bucket_arn, local.vector_bucket_arn]
  )))
}

module "iam" {
  source = "../../terraform/modules/iam-ssm"

  name_prefix = "${var.project_name}-${var.environment}"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  parameter_arns = [
    "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
  ]

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
  source = "../../terraform/modules/security-group"

  name_prefix = "${var.project_name}-${var.environment}"
  vpc_id      = data.aws_vpc.default.id
  description = "Security Group para RAG Pipeline Streamlit"

  ingress_rules = var.app_runtime == "streamlit" ? [
    {
      from_port   = var.app_port
      to_port     = var.app_port
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
      description = "Streamlit app access from authorized IP"
    }
  ] : []

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
    data_path                     = "/mnt/data"
    fallback_path                 = "/var/lib/app-data"
  })
}

module "ec2" {
  source = "../../terraform/modules/ec2-spot"

  name_prefix = "${var.project_name}-${var.environment}"

  instance_type = var.instance_type

  subnet_id              = local.subnet_id
  vpc_security_group_ids = [module.security_group.security_group_id]

  iam_instance_profile = module.iam.instance_profile_name

  spot_instance_type    = "one-time"
  interruption_behavior = "terminate"
  spot_max_price        = var.spot_max_price

  root_volume_size       = var.root_volume_size
  root_volume_type       = "gp3"
  root_volume_encrypted  = true
  root_volume_iops       = 3000
  root_volume_throughput = 125

  user_data                   = local.user_data_rendered
  user_data_replace_on_change = true

  require_imdsv2 = true

  detailed_monitoring = var.enable_detailed_monitoring

  tags = {
    Environment = var.environment
    App         = "streamlit-rag"
    Backup      = "false"
  }
}

