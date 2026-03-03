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
APP_PORT="${app_port}"
DATA_PATH="${data_path}"
FALLBACK_PATH="${fallback_path}"

APP_BASE="/opt/app"
CLONE_PATH="$APP_BASE/$APP_NAME"
VENV_PATH="$APP_BASE/venv"
USERNAME="ubuntu"

#
# 2. DEPENDÊNCIAS MÍNIMAS
#
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

apt-get install -y \
    git curl wget \
    python3 python3-venv python3-pip \
    build-essential \
    sqlite3

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
# 5. SETUP PYTHON
#
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

pip install --upgrade pip setuptools wheel

if [ -f "$WORK_DIR/requirements.txt" ]; then
    echo "Instalando dependências do requirements.txt..."
    pip install -r "$WORK_DIR/requirements.txt"
else
    echo "Instalando pacotes padrão..."
    pip install \
        streamlit \
        openai \
        langchain langchain-openai langchain-community \
        faiss-cpu \
        pymupdf \
        python-dotenv
fi

#
# 6. CONFIGURAR SQLITE
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
# 7. SYSTEMD SERVICE - STREAMLIT
#
cat > /etc/systemd/system/streamlit.service << 'SERVICE'
[Unit]
Description=Chat myPDF - Streamlit App
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

ExecStart=VENV_PLACEHOLDER/bin/streamlit run ENTRY_PLACEHOLDER --server.port=PORT_PLACEHOLDER --server.address=0.0.0.0
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

#
# 8. SUBSTITUIR PLACEHOLDERS
#
sed -i "s|USERNAME_PLACEHOLDER|$USERNAME|g" /etc/systemd/system/streamlit.service
sed -i "s|WORKDIR_PLACEHOLDER|$WORK_DIR|g" /etc/systemd/system/streamlit.service
sed -i "s|VENV_PLACEHOLDER|$VENV_PATH|g" /etc/systemd/system/streamlit.service
sed -i "s|ENTRY_PLACEHOLDER|$FOUND_FILE|g" /etc/systemd/system/streamlit.service
sed -i "s|DB_PATH_PLACEHOLDER|$DB_PATH|g" /etc/systemd/system/streamlit.service
sed -i "s|DATA_PATH_PLACEHOLDER|$FALLBACK_PATH|g" /etc/systemd/system/streamlit.service
sed -i "s|PORT_PLACEHOLDER|$APP_PORT|g" /etc/systemd/system/streamlit.service

#
# 9. PERMISSÕES E START
#
chown -R $USERNAME:$USERNAME "$APP_BASE"
chmod 755 "$APP_BASE"

systemctl daemon-reload
systemctl enable streamlit
systemctl start streamlit

echo "==== COMPLETED: $(date -Is) ===="