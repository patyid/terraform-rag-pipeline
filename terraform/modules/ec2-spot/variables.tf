# 
# VARIABLES: EC2 Spot Instance
# 

variable "name_prefix" {
  description = "Prefixo para nomeação dos recursos"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t3.medium"
}

variable "ami_name_pattern" {
  description = "Padrão de nome da AMI (ex: ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*)"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "ami_owners" {
  description = "IDs dos owners da AMI"
  type        = list(string)
  default     = ["099720109477"] # Canonical
}

variable "ami_architecture" {
  description = "Arquitetura da AMI (x86_64 ou arm64)"
  type        = string
  default     = "x86_64"
}

variable "iam_instance_profile" {
  description = "Nome do IAM Instance Profile"
  type        = string
  default     = null
}

variable "vpc_security_group_ids" {
  description = "Lista de IDs dos Security Groups"
  type        = list(string)
}

variable "subnet_id" {
  description = "ID da subnet"
  type        = string
}

variable "key_name" {
  description = "Nome do par de chaves SSH"
  type        = string
  default     = null
}

# Spot Options
variable "spot_instance_type" {
  description = "Tipo de spot: one-time ou persistent"
  type        = string
  default     = "one-time"
}

variable "interruption_behavior" {
  description = "Comportamento ao interromper: terminate, stop ou hibernate"
  type        = string
  default     = "terminate"
}

variable "spot_max_price" {
  description = "Preço máximo para spot (null = preço on-demand)"
  type        = string
  default     = null
}

# Root Volume
variable "root_volume_enabled" {
  description = "Habilitar configuração do volume raiz"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Tamanho do volume raiz em GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Tipo do volume (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Criptografar volume raiz"
  type        = bool
  default     = true
}

variable "root_volume_delete_on_termination" {
  description = "Deletar volume ao terminar instância"
  type        = bool
  default     = true
}

variable "root_volume_iops" {
  description = "IOPS para volume (gp3, io1, io2)"
  type        = number
  default     = null
}

variable "root_volume_throughput" {
  description = "Throughput para gp3 em MiB/s"
  type        = number
  default     = null
}

# User Data
variable "user_data" {
  description = "Script de user data"
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Substituir instância quando user_data mudar"
  type        = bool
  default     = true
}

# Security
variable "require_imdsv2" {
  description = "Exigir IMDSv2 (mais seguro)"
  type        = bool
  default     = true
}

variable "detailed_monitoring" {
  description = "Habilitar monitoramento detalhado do CloudWatch"
  type        = bool
  default     = false
}

# Lifecycle
variable "ignore_changes" {
  description = "Atributos para ignorar mudanças no lifecycle"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}