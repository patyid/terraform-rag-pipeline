# 
# VARIABLES: Security Group
# 

variable "name_prefix" {
  description = "Prefixo para nomeação do Security Group"
  type        = string
}

variable "description" {
  description = "Descrição do Security Group"
  type        = string
  default     = "Security Group gerenciado por Terraform"
}

variable "vpc_id" {
  description = "ID da VPC onde o SG será criado"
  type        = string
}

variable "ingress_rules" {
  description = "Lista de regras de ingress"
  type = list(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    source_security_group_id = optional(string)
    self                     = optional(bool)
    description              = optional(string)
  }))
  default = []
}

variable "egress_rules" {
  description = "Lista de regras de egress"
  type = list(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    source_security_group_id = optional(string)
    self                     = optional(bool)
    description              = optional(string)
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "KMS key ID or ARN (optional) used to encrypt the OpenAI API key parameter."
  type        = string
  default     = ""
}

variable "openai_api_key_parameter_name" {
  description = "SSM Parameter Store name for the OpenAI API key (SecureString)."
  type        = string
  default     = "/rag-pipeline/openai-api-key"
}

variable "openai_api_key" {
  description = "OpenAI API Key value stored in SSM (empty to skip parameter creation)."
  type        = string
  sensitive   = true
  default     = ""
}
