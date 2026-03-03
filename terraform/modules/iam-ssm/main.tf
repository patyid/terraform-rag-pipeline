data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

locals {
  role_name             = "${var.name_prefix}-ssm-role"
  instance_profile_name = "${var.name_prefix}-instance-profile"
  parameter_resources = length(var.parameter_arns) > 0 ? var.parameter_arns : [
    "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.name_prefix}/*"
  ]
  secret_resources = length(var.secret_arns) > 0 ? var.secret_arns : [
    "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/*"
  ]
  kms_resources = var.kms_key_arns
  s3_resource_default = [
    "arn:aws:s3:::*",
    "arn:aws:s3:::*/*"
  ]
  s3_resources          = length(var.s3_bucket_arns) > 0 ? var.s3_bucket_arns : local.s3_resource_default
  role_tags             = merge({ Name = local.role_name }, var.tags)
  instance_profile_tags = merge({ Name = local.instance_profile_name }, var.tags)
  parameter_policy_entry = {
    Effect = "Allow"
    Action = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    Resource = local.parameter_resources
  }
  secrets_policy_entries = concat(
    [local.parameter_policy_entry],
    length(local.secret_resources) > 0 ? [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = local.secret_resources
      }
    ] : [],
    length(local.kms_resources) > 0 ? [
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = local.kms_resources
      }
    ] : []
  )
  s3_policy_entries = [
    {
      Effect   = "Allow"
      Action   = var.s3_actions
      Resource = local.s3_resources
    }
  ]
}

resource "aws_iam_role" "this" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "IAM role para instâncias EC2 com SSM e acesso a recursos secretos"
  tags               = local.role_tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "secrets_access" {
  count = var.secrets_access_enabled ? 1 : 0

  name = "${var.name_prefix}-secrets-policy"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.secrets_policy_entries
  })
}

resource "aws_iam_role_policy" "s3_access" {
  count = var.s3_access_enabled ? 1 : 0

  name = "${var.name_prefix}-s3-policy"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.s3_policy_entries
  })
}

resource "aws_iam_role_policy" "custom" {
  count = var.custom_policy_enabled && length(var.custom_policy_statements) > 0 ? 1 : 0

  name = "${var.name_prefix}-custom-policy"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.custom_policy_statements
  })
}

resource "aws_iam_instance_profile" "this" {
  name = local.instance_profile_name
  role = aws_iam_role.this.name

  tags = local.instance_profile_tags
}
