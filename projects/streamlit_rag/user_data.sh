#!/bin/bash
#
# USER DATA - Chat myPDF (RAG com OpenAI API)
# Infra bootstrap ONLY (sem secrets)
#

set -euxo pipefail

exec > >(tee /var/log/user-data.log) 2>&1
echo "==== STARTED: $(date -Is) ===="

#
# 1. CONFIGURAÇÕES (via Terraform templatefile)
#
ENTRY_POINT="${app_entry_point}"
APP_RUNTIME="${app_runtime}"
APP_ARGS_RAW="${app_args}"
APP_AUTOSTART="${app_autostart}"
APP_PORT="${app_port}"
AWS_REGION="${aws_region}"
OPENAI_API_KEY_PARAMETER_NAME="${openai_api_key_parameter_name}"
PDF_BUCKET_NAME="${pdf_bucket_name}"
VECTOR_BUCKET_NAME="${vector_store_bucket_name}"
VECTOR_DB_NAME="${vector_db_name}"
VECTOR_STORE_PREFIX="${vector_store_prefix}"
EMBEDDING_MODEL="${embedding_model}"
CHAT_MODEL="${chat_model}"
DATA_PATH="${data_path}"
FALLBACK_PATH="${fallback_path}"
APP_S3_BUCKET="${app_s3_bucket}"
APP_S3_KEY="${app_s3_key}"

APP_BASE="/opt/app"
VENV_PATH="$APP_BASE/venv"
USERNAME="ubuntu"

#
# 2. DEPENDÊNCIAS DO SISTEMA (mínimas para Streamlit + LangChain)
#
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

apt-get install -y \
    curl wget \
    python3 python3-venv python3-pip \
    build-essential \
    awscli

#
# 3. CONFIGURAR DIRETÓRIO DE DADOS
#
mkdir -p "$FALLBACK_PATH"/{uploads,vectors,logs}
chown -R $USERNAME:$USERNAME "$FALLBACK_PATH"

#
# 4. DEPLOY DA APLICAÇÃO (sem clone de repo)
#
mkdir -p "$APP_BASE"

WORK_DIR="$APP_BASE/app"
mkdir -p "$WORK_DIR"

# Baixa o app do S3 (obrigatório).
if [ -z "$APP_S3_BUCKET" ] || [ -z "$APP_S3_KEY" ]; then
  echo "ERRO: app_s3_bucket e app_s3_key são obrigatórios."
  exit 1
fi

echo "Baixando app de s3://$APP_S3_BUCKET/$APP_S3_KEY"
aws s3 cp "s3://$APP_S3_BUCKET/$APP_S3_KEY" "$WORK_DIR/$ENTRY_POINT"

cat > "$WORK_DIR/requirements.txt" << 'REQS'
# Streamlit
streamlit==1.38.0

# LangChain ecosystem
langchain==0.3.0
langchain-community==0.3.0
langchain-openai==0.2.0
langchain-text-splitters==0.3.0

# Vector store
faiss-cpu==1.8.0

# OpenAI
openai==1.45.0
tiktoken==0.7.0
httpx==0.27.2

# AWS + config
boto3==1.35.0
botocore==1.35.0
pydantic==2.9.0
pydantic-settings==2.5.0
python-dotenv==1.0.1
REQS

FOUND_FILE="$WORK_DIR/$ENTRY_POINT"
if [ ! -f "$FOUND_FILE" ]; then
    echo "ERRO: Entry point '$FOUND_FILE' não encontrado!"
    exit 1
fi

#
# 5. SETUP PYTHON E DEPENDÊNCIAS
#
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

pip install --upgrade pip setuptools wheel

echo "Instalando dependências do requirements.txt..."
pip install -r "$WORK_DIR/requirements.txt"

#
# 6. ARQUIVOS AUXILIARES (ARGS + SECRETS)
#
mkdir -p "$APP_BASE"
echo -n "$APP_ARGS_RAW" > "$APP_BASE/app.args"
chown $USERNAME:$USERNAME "$APP_BASE/app.args"
chmod 644 "$APP_BASE/app.args"

cat > "$APP_BASE/load_secrets.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

REGION="AWS_REGION_PLACEHOLDER"
PARAM_NAME="PARAM_NAME_PLACEHOLDER"
ENV_FILE="ENV_FILE_PLACEHOLDER"

value="$(aws ssm get-parameter --name "$PARAM_NAME" --with-decryption --query 'Parameter.Value' --output text --region "$REGION" 2>/dev/null || true)"
if [ -n "$value" ] && [ "$value" != "None" ]; then
  umask 077
  printf "OPENAI_API_KEY=%s\n" "$value" > "$ENV_FILE"
else
  echo "WARN: não foi possível carregar OPENAI_API_KEY de $PARAM_NAME (SSM). Prosseguindo sem a chave." >&2
fi
EOF

chmod 755 "$APP_BASE/load_secrets.sh"
sed -i "s|AWS_REGION_PLACEHOLDER|$AWS_REGION|g" "$APP_BASE/load_secrets.sh"
sed -i "s|PARAM_NAME_PLACEHOLDER|$OPENAI_API_KEY_PARAMETER_NAME|g" "$APP_BASE/load_secrets.sh"
sed -i "s|ENV_FILE_PLACEHOLDER|$APP_BASE/app.env|g" "$APP_BASE/load_secrets.sh"
chown $USERNAME:$USERNAME "$APP_BASE/load_secrets.sh"

cat > "$APP_BASE/run_app.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

VENV_PATH="VENV_PLACEHOLDER"
ENTRY_FILE="ENTRY_PLACEHOLDER"
RUNTIME="RUNTIME_PLACEHOLDER"
ARGS_FILE="ARGS_FILE_PLACEHOLDER"

args=""
if [ -f "$ARGS_FILE" ]; then
  args="$(cat "$ARGS_FILE" || true)"
fi

extra_args=()
if [ -n "$${args:-}" ]; then
  # split simples por whitespace (sem suporte a quoting complexo)
  read -r -a extra_args <<<"$args"
fi

if [ "$RUNTIME" = "streamlit" ]; then
  exec "$VENV_PATH/bin/streamlit" run "$ENTRY_FILE" --server.address=0.0.0.0 "$${extra_args[@]}"
fi

exec "$VENV_PATH/bin/python" "$ENTRY_FILE" "$${extra_args[@]}"
EOF

chmod 755 "$APP_BASE/run_app.sh"
sed -i "s|VENV_PLACEHOLDER|$VENV_PATH|g" "$APP_BASE/run_app.sh"
sed -i "s|ENTRY_PLACEHOLDER|$FOUND_FILE|g" "$APP_BASE/run_app.sh"
sed -i "s|RUNTIME_PLACEHOLDER|$APP_RUNTIME|g" "$APP_BASE/run_app.sh"
sed -i "s|ARGS_FILE_PLACEHOLDER|$APP_BASE/app.args|g" "$APP_BASE/run_app.sh"
chown $USERNAME:$USERNAME "$APP_BASE/run_app.sh"

#
# 7. SYSTEMD SERVICE
#
SERVICE_NAME="streamlit"
if [ "$APP_RUNTIME" != "streamlit" ]; then
  SERVICE_NAME="pipeline"
fi

cat > "/etc/systemd/system/$${SERVICE_NAME}.service" << 'SERVICE'
[Unit]
Description=RAG App Service
After=network.target

[Service]
Type=simple
User=USERNAME_PLACEHOLDER
WorkingDirectory=WORKDIR_PLACEHOLDER
Environment=PYTHONUNBUFFERED=1
Environment=HOME=/home/USERNAME_PLACEHOLDER
Environment=PATH=VENV_PLACEHOLDER/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=DATA_PATH=DATA_PATH_PLACEHOLDER
Environment=STREAMLIT_SERVER_PORT=PORT_PLACEHOLDER
Environment=STREAMLIT_SERVER_ADDRESS=0.0.0.0
Environment=STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
Environment=PYTHONPATH=WORKDIR_PLACEHOLDER
Environment=VECTOR_STORE_BUCKET=VECTOR_BUCKET_PLACEHOLDER
Environment=VECTOR_DB_NAME=VECTOR_DB_NAME_PLACEHOLDER
Environment=VECTOR_STORE_PREFIX=VECTOR_STORE_PREFIX_PLACEHOLDER
Environment=EMBEDDING_MODEL=EMBEDDING_MODEL_PLACEHOLDER
Environment=CHAT_MODEL=CHAT_MODEL_PLACEHOLDER
EnvironmentFile=-/opt/app/app.env

ExecStartPre=/opt/app/load_secrets.sh
ExecStart=/opt/app/run_app.sh
ExecStartPost=/bin/bash -c "sleep 5; /usr/local/bin/streamlit-healthcheck.sh PORT_PLACEHOLDER || true"
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

#
# 9. SUBSTITUIR PLACEHOLDERS
#
UNIT_FILE="/etc/systemd/system/$${SERVICE_NAME}.service"
sed -i "s|USERNAME_PLACEHOLDER|$USERNAME|g" "$UNIT_FILE"
sed -i "s|WORKDIR_PLACEHOLDER|$WORK_DIR|g" "$UNIT_FILE"
sed -i "s|VENV_PLACEHOLDER|$VENV_PATH|g" "$UNIT_FILE"
sed -i "s|ENTRY_PLACEHOLDER|$FOUND_FILE|g" "$UNIT_FILE"
sed -i "s|DATA_PATH_PLACEHOLDER|$FALLBACK_PATH|g" "$UNIT_FILE"
sed -i "s|PORT_PLACEHOLDER|$APP_PORT|g" "$UNIT_FILE"
sed -i "s|VECTOR_BUCKET_PLACEHOLDER|$VECTOR_BUCKET_NAME|g" "$UNIT_FILE"
sed -i "s|VECTOR_DB_NAME_PLACEHOLDER|$VECTOR_DB_NAME|g" "$UNIT_FILE"
sed -i "s|VECTOR_STORE_PREFIX_PLACEHOLDER|$VECTOR_STORE_PREFIX|g" "$UNIT_FILE"
sed -i "s|EMBEDDING_MODEL_PLACEHOLDER|$EMBEDDING_MODEL|g" "$UNIT_FILE"
sed -i "s|CHAT_MODEL_PLACEHOLDER|$CHAT_MODEL|g" "$UNIT_FILE"

#
# 10. PERMISSÕES E START
#
chown -R $USERNAME:$USERNAME "$APP_BASE"
chmod 755 "$APP_BASE"

systemctl daemon-reload

if [ "$APP_AUTOSTART" = "true" ]; then
  systemctl enable "$SERVICE_NAME"
  systemctl start "$SERVICE_NAME"
else
  echo "APP_AUTOSTART=false: serviço $${SERVICE_NAME} instalado, mas não iniciado automaticamente."
fi

echo "==== COMPLETED: $(date -Is) ===="

#
# 11. HEALTHCHECK BÁSICO
#
cat > /usr/local/bin/streamlit-healthcheck.sh << 'HC'
#!/bin/bash
set -euo pipefail

PORT="$${1:-8501}"
curl -fsS "http://127.0.0.1:$${PORT}/_stcore/health" >/dev/null
HC
chmod 755 /usr/local/bin/streamlit-healthcheck.sh
