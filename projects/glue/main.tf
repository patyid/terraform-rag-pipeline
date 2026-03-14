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
    key     = "state/rag-pipeline-glue.tfstate"
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

data "aws_caller_identity" "current" {}

data "aws_kms_alias" "ssm_default" {
  name = "alias/aws/ssm"
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

data "archive_file" "rag_pipeline_app" {
  count = var.glue_build_app_zip ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/${var.rag_pipeline_app_dir}"
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

resource "aws_s3_bucket" "glue_assets" {
  count = var.glue_assets_bucket_name == "" ? 1 : 0

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

locals {
  pdf_bucket_arn = var.pdf_bucket_name != "" ? "arn:aws:s3:::${var.pdf_bucket_name}" : ""

  vector_bucket_name_effective = var.vector_store_bucket_name != "" ? var.vector_store_bucket_name : try(module.vector_db[0].bucket_name, "")
  vector_bucket_arn            = local.vector_bucket_name_effective != "" ? "arn:aws:s3:::${local.vector_bucket_name_effective}" : ""

  glue_assets_bucket_name_effective = var.glue_assets_bucket_name != "" ? var.glue_assets_bucket_name : try(aws_s3_bucket.glue_assets[0].bucket, "")
  glue_assets_bucket_arn            = local.glue_assets_bucket_name_effective != "" ? "arn:aws:s3:::${local.glue_assets_bucket_name_effective}" : ""

  rag_pipeline_app_requirements_path    = "${path.module}/${var.rag_pipeline_app_dir}/requirements.txt"
  rag_pipeline_app_requirements_content = file(local.rag_pipeline_app_requirements_path)

  rag_pipeline_app_additional_python_modules = join(",", [
    for line in split("\n", local.rag_pipeline_app_requirements_content) :
    trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ])

  glue_additional_python_modules = var.glue_additional_python_modules_override != "" ? var.glue_additional_python_modules_override : local.rag_pipeline_app_additional_python_modules
}

resource "aws_s3_object" "glue_job_script" {
  bucket       = local.glue_assets_bucket_name_effective
  key          = var.glue_script_s3_key
  source       = "${path.module}/glue/rag_pipeline_job.py"
  content_type = "text/x-python"
  etag         = filemd5("${path.module}/glue/rag_pipeline_job.py")
}

resource "aws_s3_object" "rag_pipeline_app_zip" {
  bucket = local.glue_assets_bucket_name_effective
  key    = var.glue_artifact_s3_key
  source = var.glue_build_app_zip ? data.archive_file.rag_pipeline_app[0].output_path : "${path.module}/glue/dist/rag-pipeline-app.zip"

  etag = var.glue_build_app_zip ? data.archive_file.rag_pipeline_app[0].output_md5 : null
}

resource "aws_iam_role" "glue_ingestion" {
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
  role       = aws_iam_role.glue_ingestion.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_ingestion_inline" {
  name = "${var.project_name}-${var.environment}-glue-ingestion-inline"
  role = aws_iam_role.glue_ingestion.id

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
      },
      {
        Effect = "Allow"
        Action = [
          "textract:StartDocumentTextDetection",
          "textract:GetDocumentTextDetection"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_glue_job" "rag_pipeline_ingestion" {
  name              = "${var.project_name}-${var.environment}-rag-pipeline-ingestion"
  role_arn          = aws_iam_role.glue_ingestion.arn
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
    "--vector-bucket"             = local.vector_bucket_name_effective
  }

  depends_on = [
    aws_s3_object.glue_job_script,
    aws_s3_object.rag_pipeline_app_zip,
    aws_iam_role_policy_attachment.glue_service_role,
    aws_iam_role_policy.glue_ingestion_inline,
  ]
}
