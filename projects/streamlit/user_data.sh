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
APP_REPO="${app_git_repo}"
APP_BRANCH="${app_git_branch}"
APP_NAME="${app_dir_name}"
ENTRY_POINT="${app_entry_point}"
APP_RUNTIME="${app_runtime}"
APP_ARGS_RAW="${app_args}"
APP_AUTOSTART="${app_autostart}"
APP_PORT="${app_port}"
AWS_REGION="${aws_region}"
OPENAI_API_KEY_PARAMETER_NAME="${openai_api_key_parameter_name}"
PDF_BUCKET_NAME="${pdf_bucket_name}"
VECTOR_BUCKET_NAME="${vector_store_bucket_name}"
DATA_PATH="${data_path}"
FALLBACK_PATH="${fallback_path}"

APP_BASE="/opt/app"
CLONE_PATH="$APP_BASE/$APP_NAME"
VENV_PATH="$APP_BASE/venv"
USERNAME="ubuntu"

#
# 2. DEPENDÊNCIAS DO SISTEMA (incluindo OCR para PDFs de imagem)
#
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

apt-get install -y \
    git curl wget \
    python3 python3-venv python3-pip \
    build-essential \
    sqlite3 \
    awscli \
    tesseract-ocr \
    tesseract-ocr-por \
    tesseract-ocr-eng \
    poppler-utils \
    libpoppler-cpp-dev \
    pkg-config \
    libmagic1

#
# 3. CONFIGURAR DIRETÓRIO DE DADOS
#
mkdir -p "$FALLBACK_PATH"/{uploads,vectors,logs}
chown -R $USERNAME:$USERNAME "$FALLBACK_PATH"

#
# 4. DEPLOY DA APLICAÇÃO
#
mkdir -p "$APP_BASE"

if [ -d "$CLONE_PATH/.git" ]; then
    echo "Atualizando repositório..."
    cd "$CLONE_PATH"
    git fetch origin
    git checkout "$APP_BRANCH"
    git pull origin "$APP_BRANCH"
else
    echo "Clonando repositório..."
    git clone --branch "$APP_BRANCH" --depth 1 "$APP_REPO" "$CLONE_PATH"
fi

FOUND_FILE=$(find "$CLONE_PATH" -name "$ENTRY_POINT" -type f | head -n 1)
if [ -z "$FOUND_FILE" ]; then
    echo "ERRO: Entry point '$ENTRY_POINT' não encontrado!"
    exit 1
fi

WORK_DIR=$(dirname "$FOUND_FILE")

#
# 5. SETUP PYTHON E DEPENDÊNCIAS
#
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

pip install --upgrade pip setuptools wheel

# Verifica se existe requirements.txt no projeto
if [ -f "$WORK_DIR/requirements.txt" ]; then
    echo "Instalando dependências do requirements.txt..."
    pip install -r "$WORK_DIR/requirements.txt"
else
    echo "Criando requirements.txt com dependências do RAG..."
    cat > "$WORK_DIR/requirements.txt" << 'EOF'
# LangChain Ecosystem
langchain==0.3.0
langchain-community==0.3.0
langchain-openai==0.2.0
langchain-text-splitters==0.3.0

# PDF Processing & OCR
pymupdf==1.24.10
pdf2image==1.17.0
pytesseract==0.3.13
pdfplumber==0.11.4
unstructured==0.15.0
unstructured-inference==0.7.36
pillow==10.4.0

# Vector Store & ML
faiss-cpu==1.8.0
numpy==1.26.4
scipy==1.14.0

# OpenAI & Tokenization
openai==1.45.0
tiktoken==0.7.0

# AWS S3
boto3==1.35.0
botocore==1.35.0

# Data & Config
pydantic==2.9.0
pydantic-settings==2.5.0
python-dotenv==1.0.1
pandas==2.2.2
pyarrow==17.0.0

# Utilities
tqdm==4.66.5
tenacity==8.5.0
streamlit==1.38.0
EOF
    
    pip install -r "$WORK_DIR/requirements.txt"
fi

# Instala pacotes adicionais específicos se ainda não estiverem no requirements
echo "Verificando pacotes adicionais..."
pip install --upgrade langchain-openai faiss-cpu pymupdf tiktoken boto3 pydantic-settings python-dotenv tqdm || true

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
# 7. CONFIGURAR SQLITE (usado pelo app Streamlit)
#
DB_PATH="$FALLBACK_PATH/chat_history.db"

sudo -u $USERNAME sqlite3 "$DB_PATH" "
CREATE TABLE IF NOT EXISTS message_store (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_session ON message_store(session_id);
"

chmod 644 "$DB_PATH"

#
# 8. SYSTEMD SERVICE
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
Environment=CHAT_HISTORY_DB=DB_PATH_PLACEHOLDER
Environment=DATA_PATH=DATA_PATH_PLACEHOLDER
Environment=STREAMLIT_SERVER_PORT=PORT_PLACEHOLDER
Environment=STREAMLIT_SERVER_ADDRESS=0.0.0.0
Environment=STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
Environment=PYTHONPATH=WORKDIR_PLACEHOLDER
EnvironmentFile=-/opt/app/app.env

ExecStartPre=/opt/app/load_secrets.sh
ExecStart=/opt/app/run_app.sh
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
sed -i "s|DB_PATH_PLACEHOLDER|$DB_PATH|g" "$UNIT_FILE"
sed -i "s|DATA_PATH_PLACEHOLDER|$FALLBACK_PATH|g" "$UNIT_FILE"
sed -i "s|PORT_PLACEHOLDER|$APP_PORT|g" "$UNIT_FILE"

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
