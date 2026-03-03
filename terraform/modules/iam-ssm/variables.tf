# 
# VARIABLES: IAM Role para SSM
# 

variable "name_prefix" {
  description = "Prefixo para nomeação dos recursos IAM"
  type        = string
}

variable "managed_policy_arns" {
  description = "Lista de ARNs de políticas AWS gerenciadas para attach"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

# Custom Policy
variable "custom_policy_enabled" {
  description = "Habilitar policy inline customizada"
  type        = bool
  default     = false
}

variable "custom_policy_statements" {
  description = "Lista de statements para policy customizada"
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
    Condition = optional(map(any))
  }))
  default = []
}

# Secrets Manager / Parameter Store Access
variable "secrets_access_enabled" {
  description = "Habilitar acesso a Secrets Manager e Parameter Store"
  type        = bool
  default     = false
}

variable "secret_arns" {
  description = "Lista específica de ARNs de secrets (vazio = wildcard com prefixo)"
  type        = list(string)
  default     = []
}

variable "parameter_arns" {
  description = "Lista específica de ARNs de parameters (vazio = wildcard com prefixo)"
  type        = list(string)
  default     = []
}

# S3 Access
variable "s3_access_enabled" {
  description = "Habilitar acesso a S3"
  type        = bool
  default     = false
}

variable "s3_actions" {
  description = "Ações permitidas no S3"
  type        = list(string)
  default = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:ListBucket"
  ]
}

variable "s3_bucket_arns" {
  description = "ARNs dos buckets S3 permitidos (vazio = todos)"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs that the role may use to decrypt SecureString parameters."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags para os recursos IAM"
  type        = map(string)
  default     = {}
}