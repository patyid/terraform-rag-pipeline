variable "description" {
  description = "Descrição da KMS key"
  type        = string
  default     = "KMS key for Secure Parameters"
}

variable "alias_name" {
  description = "Nome do alias da KMS"
  type        = string
}

variable "allowed_role_arns" {
  description = "Lista de ARNs das roles que podem usar a chave"
  type        = list(string)
  default     = []
}

variable "deletion_window_in_days" {
  description = "Janela para deletar a chave"
  type        = number
  default     = 7
}

variable "enable_key_rotation" {
  description = "Habilita rotação automática"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags da KMS"
  type        = map(string)
  default     = {}
}