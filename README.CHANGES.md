# Mudanças (separação em 2 projetos)

Este repositório foi reorganizado para evitar um único stack Terraform “grande” misturando **ingestão (batch)** e **serving (chatbot)**.

## O que mudou

- O Terraform foi separado em dois **root modules** independentes:
  - `projects/glue/`: infra do **AWS Glue** para ingestão (lê PDFs do S3 e grava FAISS no S3).
  - `projects/streamlit/`: infra de **EC2 Spot + Streamlit** para rodar o chatbot.
- Os módulos reaproveitáveis permanecem em `terraform/modules/`.
- O stack antigo combinado foi movido para `legacy/combined-terraform/terraform/` (mantido só para referência).

## Projeto 1 — `projects/glue/` (ingestão)

**O que provisiona**

- `aws_glue_job` com `worker_type = "G.1X"` e `glue_number_of_workers` limitado a **no máximo 10** (via validação de variável).
- IAM role do Glue com permissões:
  - S3 (ler PDFs no `pdf_bucket_name`, ler/escrever o vector store no bucket efetivo, ler script/zip no bucket de assets).
  - SSM Parameter Store (`ssm:GetParameter/GetParameters` + `kms:Decrypt`) no parâmetro `openai_api_key_parameter_name`.

**Pré-requisito (código da ingestão)**

O job executa o `rag-pipeline-app`. Clone dentro do projeto:

`git clone https://github.com/patyid/rag-pipeline-app.git projects/glue/rag-pipeline-app`

**Como aplicar**

- Ajuste vars em `projects/glue/enviroments/dev/terraform.tfvars` (principalmente `pdf_bucket_name`).
- Rode:
  - `terraform -chdir=projects/glue apply -var-file=enviroments/dev/terraform.tfvars`
- Para iniciar o job, use o output `glue_start_job_run`.

**OpenAI API Key (SSM Parameter Store)**

Para evitar gravar segredos no `terraform.tfstate`, o parâmetro **não é criado via Terraform**. Crie manualmente uma vez:

`aws ssm put-parameter --name /rag-pipeline/openai-api-key --type SecureString --value 'SUA_CHAVE' --overwrite --region us-east-1`

**Notas**

- Dependências Python do Glue são derivadas do `requirements.txt` do `rag-pipeline-app`. Se alguma falhar no runtime do Glue, use `glue_additional_python_modules_override`.

## Projeto 2 — `projects/streamlit/` (chatbot)

**O que provisiona**

- EC2 Spot + Security Group + IAM/SSM (mesmo comportamento do stack original, mas isolado).
- `user_data.sh` **não** clona/instala mais o repo de vetorização (nem usa `app_git_branch_vector`).

**Como aplicar**

- Ajuste vars em `projects/streamlit/enviroments/dev/terraform.tfvars` (especialmente `allowed_cidr`).
- Rode:
  - `terraform -chdir=projects/streamlit apply -var-file=enviroments/dev/terraform.tfvars`

## Pasta `legacy/`

- `legacy/combined-terraform/terraform/` contém o stack antigo (Glue + EC2 no mesmo root).
- Recomendação: manter só como histórico e usar daqui pra frente apenas `projects/glue` e `projects/streamlit`.

## Criar o parameter store
- `aws ssm put-parameter --name /rag-pipeline/openai-api-key --type SecureString --value 'SUA_CHAVE' --overwrite --region us-east-1`
