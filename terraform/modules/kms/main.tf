############################################
# DATA SOURCES
############################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

############################################
# KMS KEY
############################################

resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  tags                    = var.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # Permissão total para o root da conta
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },

      # Permissão para roles específicas usarem decrypt
      {
        Sid    = "AllowUseOfKey"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_role_arns
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# ALIAS
############################################

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.this.key_id
}