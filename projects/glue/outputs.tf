output "glue_job_name" {
  description = "Nome do Glue Job de ingestão"
  value       = aws_glue_job.rag_pipeline_ingestion.name
}

output "glue_start_job_run" {
  description = "Comando AWS CLI para iniciar o Glue Job"
  value       = "aws glue start-job-run --job-name ${aws_glue_job.rag_pipeline_ingestion.name} --region ${var.region}"
}

output "vector_store_bucket_name" {
  description = "Bucket efetivo onde os vector stores são gravados"
  value       = local.vector_bucket_name_effective
}

output "glue_assets_bucket_name" {
  description = "Bucket efetivo onde ficam os assets do Glue"
  value       = local.glue_assets_bucket_name_effective
}

