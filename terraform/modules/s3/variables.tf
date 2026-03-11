variable "bucket_name" {
  description = "Nome do bucket S3 que armazenará os vector stores"
  type        = string
  default     = "rag-pipeline-vector-db"
}

variable "tags" {
  description = "Tags aplicadas ao bucket"
  type        = map(string)
  default     = {}
}
