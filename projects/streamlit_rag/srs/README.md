# Streamlit RAG (FAISS + OpenAI)

Aplicação Streamlit que baixa um índice FAISS do S3, roda retrieval com LangChain + OpenAI e exibe respostas com as fontes e páginas utilizadas.

## Visão geral

1. O índice FAISS é guardado no bucket configurado como `VECTOR_STORE_BUCKET` em `vector-stores/<VECTOR_DB_NAME>/` (gerado pelo Glue em `projects/glue`).
2. Ao subir, o app baixa apenas os objetos alterados graças ao manifesto `.s3_manifest.json`, entregando latência previsível.
3. A cada pergunta, o app busca `k` documentos, monta o contexto com a fonte/página e envia para o LLM configurado (`CHAT_MODEL`).
4. Histórico de conversa é preservado no `st.session_state` para manter coerência enquanto a sessão estiver ativa.

## Variáveis de ambiente

### Obrigatórias
- `OPENAI_API_KEY`: chave da API OpenAI (pode vir de `.env` local ou SSM em produção).
- `VECTOR_STORE_BUCKET`: bucket S3 que contém o vector store gerado pelo Glue.

### Com valor padrão
- `VECTOR_STORE_PREFIX` (`vector-stores/`): prefixo base com <db_name> em seguida.
- `VECTOR_DB_NAME` (`vector_db`): nome do banco/índice a ser baixado.
- `EMBEDDING_MODEL` (`text-embedding-3-small`): deve coincidir com o usado na ingestão.
- `CHAT_MODEL` (`gpt-4o-mini`): modelo que alimenta o chat.
- `AWS_REGION` (`us-east-1`): região usada para `boto3`.
- `DATA_PATH` (`/mnt/data`): raiz local onde o índice é cacheado (`vectors/<db_name>`).
- `STREAMLIT_SERVER_PORT` (`8501`): porta onde o Streamlit expõe a interface.

Se estiver rodando via Terraform (`projects/streamlit_rag`), o script `user_data.sh` já injeta essas variáveis antes de iniciar o serviço.

## Executar localmente

```bash
cd projects/streamlit_rag/srs
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export OPENAI_API_KEY="sua-chave"
export VECTOR_STORE_BUCKET="nome-do-bucket"
export VECTOR_DB_NAME="vector_db"
export VECTOR_STORE_PREFIX="vector-stores/"
export AWS_REGION="us-east-1"
export DATA_PATH="/tmp/streamlit-data"

streamlit run streamlit_app.py --server.port=8501
```

O app baixará `s3://{VECTOR_STORE_BUCKET}/{VECTOR_STORE_PREFIX}{VECTOR_DB_NAME}/` para `DATA_PATH/vectors/{VECTOR_DB_NAME}` e monta o índice com o modelo de embeddings configurado.

## Deploy com Terraform (`projects/streamlit_rag`)

1. Ajuste `projects/streamlit_rag/enviroments/dev/terraform.tfvars`:
   - Defina `allowed_cidr` para seus IP(s) (o SG só permite acesso a esses CIDRs).
   - Aponte `pdf_bucket_name` e `vector_store_bucket_name` para os buckets usados pelo Glue (ou deixe o Terraform criar o bucket de vetores e sincronize os arquivos manualmente).
   - Confirme `app_s3_bucket`/`app_s3_key` para o script `srs/streamlit_app.py`.
2. Rode `terraform -chdir=projects/streamlit_rag init` e `terraform -chdir=projects/streamlit_rag apply -var-file=enviroments/dev/terraform.tfvars`.
3. O `user_data.sh`:
   - Baixa `streamlit_app.py` do bucket `app_s3_bucket`.
   - Cria um venv, instala dependências e configura `systemd` com `streamlit` como serviço.
   - Chama `/opt/app/load_secrets.sh` para puxar `OPENAI_API_KEY` do SSM (`/rag-pipeline/openai-api-key`).
   - Usa `/opt/app/run_app.sh` para passar argumentos adicionais (`app_args`).
4. O serviço `streamlit` roda com healthcheck personalizado (`/usr/local/bin/streamlit-healthcheck.sh`). O Terraform expõe o URL em `application_url` e fornece comandos SSM/em logs via outputs.

## Observações importantes

- O índice FAISS precisa ter sido gerado com o mesmo `EMBEDDING_MODEL`; caso contrário, o app falhará ao carregar o vetor.
- A autenticação com OpenAI em produção depende de `OPENAI_API_KEY` no SSM. Crie-a uma vez com `aws ssm put-parameter --name /rag-pipeline/openai-api-key --type SecureString --value 'SUA_CHAVE' --overwrite --region us-east-1`.
- Por padrão, o serviço roda em uma instância EC2 Spot (`t3.medium`/`t3.xlarge`). Use os outputs `ssm_start_session` e `cloudwatch_logs` para acessar a máquina ou acompanhar logs.
- O Streamlit exibe as fontes (arquivo/página) ao final de cada resposta para facilitar auditoria.
