# Streamlit RAG (FAISS + OpenAI)

Este app Streamlit carrega um índice FAISS salvo no S3, recupera documentos relevantes e gera respostas com a OpenAI.

## Como funciona

1. Baixa o índice FAISS do S3 (com cache local por `ETag`).
2. Faz retrieval com `k` documentos.
3. Monta contexto com fonte/página.
4. Envia para o LLM e exibe resposta com referências.

## Variáveis de ambiente

Obrigatórias:
- `OPENAI_API_KEY`
- `VECTOR_STORE_BUCKET`

Opcionais (com padrão):
- `VECTOR_STORE_PREFIX` (`vector-stores/`)
- `VECTOR_DB_NAME` (`vector_db`)
- `EMBEDDING_MODEL` (`text-embedding-3-small`)
- `CHAT_MODEL` (`gpt-4o-mini`)
- `AWS_REGION` (`us-east-1`)
- `DATA_PATH` (`/mnt/data`)

## Deploy via EC2 (user_data)

O `user_data.sh` baixa o `streamlit_app.py` de um bucket S3.
Defina no Terraform:

- `app_s3_bucket`
- `app_s3_key`

O Terraform faz o upload automático do arquivo local `srs/streamlit_app.py`
para o bucket configurado.

## Executar localmente

```bash
cd projects/streamlit_rag/srs
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export OPENAI_API_KEY="..."
export VECTOR_STORE_BUCKET="seu-bucket"
export VECTOR_STORE_PREFIX="vector-stores/"
export VECTOR_DB_NAME="vector_db"

streamlit run streamlit_app.py
```

## Observações

- O índice FAISS precisa ter sido gerado com o mesmo `EMBEDDING_MODEL`.
- O app usa histórico de conversa para coerência (configurável na sidebar).
- As fontes são exibidas ao final da resposta.
