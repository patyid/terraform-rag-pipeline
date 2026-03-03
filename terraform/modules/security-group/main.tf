# 
# MÓDULO: Security Group Parametrizável
# 

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-sg"
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name = "${var.name_prefix}-sg"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Regras de Ingress (Inbound)
resource "aws_security_group_rule" "ingress" {
  for_each = { for idx, rule in var.ingress_rules : idx => rule }

  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  security_group_id = aws_security_group.this.id

  # Uma das opções deve ser especificada
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks         = lookup(each.value, "ipv6_cidr_blocks", null)
  source_security_group_id = lookup(each.value, "source_security_group_id", null)
  self                     = lookup(each.value, "self", null)

  description = lookup(each.value, "description", "Regra ingress ${each.key}")
}

# Regras de Egress (Outbound)
resource "aws_security_group_rule" "egress" {
  for_each = { for idx, rule in var.egress_rules : idx => rule }

  type              = "egress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  security_group_id = aws_security_group.this.id

  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks         = lookup(each.value, "ipv6_cidr_blocks", null)
  source_security_group_id = lookup(each.value, "source_security_group_id", null)
  self                     = lookup(each.value, "self", null)

  description = lookup(each.value, "description", "Regra egress ${each.key}")
}

resource "aws_ssm_parameter" "openai_api_key" {
  count       = var.openai_api_key != "" ? 1 : 0
  name        = "/rag-pipeline/openai-api-key"
  description = "OpenAI API Key"
  type        = "SecureString"

  value  = var.openai_api_key
  key_id = var.kms_key_id != "" ? var.kms_key_id : null

  lifecycle {
    ignore_changes = [value]
  }
}
