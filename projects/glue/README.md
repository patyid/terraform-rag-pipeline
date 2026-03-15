# Glue Ingestion Pipeline

Este projeto Terraform provisiona o job AWS Glue responsável por ingestão de PDFs e criação do vector store FAISS usado pelo chatbot Streamlit.

## Visão geral

- O Glue job roda o pacote Python `rag-pipeline-app` (em `projects/glue/rag-pipeline-app/`) para carregar PDFs, aplicar OCR/Textract quando necessário, gerar embeddings com OpenAI e salvar o índice em S3 (`vector-stores/<db_name>/`).
- A infraestrutura inclui bucket de assets (script + zip), IAM role com permissões (SSM, S3, Textract), e o próprio Glue job com workers `G.1X`.
- O bucket de vetores pode ser informado ou criado pelo Terraform (`module.vector_db`).
- A OpenAI API Key deve estar no SSM Parameter Store em `/rag-pipeline/openai-api-key` e não é provisionada pelo Terraform.

## Estrutura importante

- `projects/glue/main.tf`: define providers, backend S3, módulos e recursos (S3 bucket, IAM, Glue job). 
- `projects/glue/variables.tf`: parametriza região, buckets, número de workers, timeouts, script S3 e diretório do app.
- `projects/glue/enviroments/dev/terraform.tfvars`: exemplo com buckets e prefixos para dev.
- `projects/glue/glue/rag_pipeline_job.py`: chama a aplicação `rag_pipeline_app`, passa argumentos e gera vector store.
- `projects/glue/rag-pipeline-app/`: código Python usado pelo Glue, com README próprio explicando execução local e argumentos.

## Pré-requisitos

1. Ter o código `rag-pipeline-app` dentro do subdiretório: `git clone https://github.com/patyid/rag-pipeline-app.git projects/glue/rag-pipeline-app`.
2. OpenAI API Key armazenada em `/rag-pipeline/openai-api-key` no Parameter Store (SecureString).
3. Buckets S3 para PDFs (existente) e para vector store (pode ser criado automaticamente pelo Terraform se `vector_store_bucket_name` ficar vazio).
4. AWS CLI configurado para a conta/região `us-east-1` e permissões para criar Glue, IAM, S3, Textract e SSM.

## Como aplicar

```bash
cd projects/glue
terraform init
# ajuste enviroments/dev/terraform.tfvars conforme seus buckets e prefixos
terraform apply -var-file=enviroments/dev/terraform.tfvars
```

O processo cria:
- Bucket de assets (se `glue_assets_bucket_name` não for informado).
- S3 objects para o script (`glue/rag_pipeline_job.py`) e artefato (`rag-pipeline-app.zip`). 
- IAM role com políticas SSM, Textract, S3 e role para o Glue job.
- O Glue job com `--additional-python-modules` derivado do `requirements.txt`.

## Executando o job

Depois do `apply`, use o output `glue_start_job_run` para disparar o job:

```bash
terraform -chdir=projects/glue output glue_start_job_run
```

Ou execute diretamente:

```bash
aws glue start-job-run --job-name <nome> --region us-east-1
```

Use o console do Glue ou CloudWatch Logs para acompanhar passar o job e depurar.

## Personalizações úteis

- `glue_pdf_prefix`: prefixo dentro do bucket de PDFs (ex: `pdfs/condominio/`).
- `glue_vector_db_name`: nome do vector store (prefixo S3 + diretório local no app).
- `glue_number_of_workers`: de 2 a 10 (validação incorporada).
- `glue_additional_python_modules_override`: passe módulos extras caso o parsing do `requirements.txt` precise ser ajustado.

## Observações

- Sempre mantenha os buckets e prefixos alinhados entre Glue e o Streamlit (mesmo `vector_db_name`/`vector-stores/<db_name>/`).
- O IAM role precisa de permissões Textract para PDFs de imagem (`textract:StartDocumentTextDetection`, `textract:GetDocumentTextDetection`).
- O vector store gerado pelo Glue é consumido pela aplicação Streamlit (`projects/streamlit_rag`).
