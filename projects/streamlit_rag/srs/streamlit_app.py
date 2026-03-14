import json
import os
from pathlib import Path
from typing import List

import boto3
import streamlit as st
from langchain_community.vectorstores import FAISS
from langchain_openai import OpenAIEmbeddings, ChatOpenAI

MANIFEST_FILENAME = ".s3_manifest.json"


def _env(name: str, default: str | None = None) -> str | None:
    """
    Returns the value of the environment variable with the given name,
    or the default value if the environment variable does not exist
    or is empty.
    """
    value = os.getenv(name) 
    return value if value is not None and value != "" else default


def _load_manifest(path: Path) -> dict:
    """
    Loads the JSON manifest stored at the given path.

    Returns an empty dictionary if the file does not exist, or if there is an error while loading the manifest.

    :param path: The path to the manifest file
    :return: The loaded manifest as a dictionary
    :rtype: dict
    """
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _save_manifest(path: Path, manifest: dict) -> None:
    """
    Saves the given manifest to the given path as a JSON file.

    :param path: The path to the file where the manifest should be saved
    :param manifest: The manifest to be saved
    :type path: Path
    :type manifest: dict
    """
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

 # Manifest com ETag por arquivo para evitar rebaixar índices já atualizados.
 # Útil para estudos futuros: o ETag muda quando o objeto muda, então usamos
 # isso como "assinatura" simples do arquivo no S3.
def _download_s3_prefix(bucket: str, prefix: str, local_dir: Path, region: str) -> None:
    s3 = boto3.client("s3", region_name=region)
    paginator = s3.get_paginator("list_objects_v2")

    local_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = local_dir / MANIFEST_FILENAME
    old_manifest = _load_manifest(manifest_path)
    new_manifest: dict[str, str] = {}

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj.get("Key")
            if not key or key.endswith("/"):
                continue
            rel_path = Path(key).relative_to(prefix)
            local_path = local_dir / rel_path
            local_path.parent.mkdir(parents=True, exist_ok=True)
            etag = (obj.get("ETag") or "").strip('"')
            new_manifest[str(rel_path)] = etag

            if old_manifest.get(str(rel_path)) == etag and local_path.exists():
                continue

            s3.download_file(bucket, key, str(local_path))

    _save_manifest(manifest_path, new_manifest)


@st.cache_resource(show_spinner=False)
def load_vectorstore() -> FAISS:
    """
    Carrega o índice FAISS do S3.

    Esta função carrega um índice FAISS de um bucket do S3. Primeiro, verifica se a variável de ambiente
    VECTOR_STORE_BUCKET está definida. Se não estiver, uma exceção RuntimeError é lançada.

    Em seguida, as variáveis de ambiente AWS_REGION, VECTOR_STORE_BUCKET, VECTOR_STORE_PREFIX e VECTOR_DB_NAME
    são obtidas usando a função _env. O prefixo do S3 é construído concatenando o prefixo base e o nome do
    banco de vetores.

    Em seguida, é determinado o diretório local onde o índice FAISS será armazenado usando o data_root
    e o db_name. É chamada a função _download_s3_prefix para baixar os arquivos do bucket do S3 para o
    diretório local.

    Depois, é obtida a variável de ambiente EMBEDDING_MODEL e é criada uma instância de OpenAIEmbeddings
    usando o modelo. Por fim, o índice FAISS é carregado do diretório local usando FAISS.load_local e é
    retornado.

    :raises RuntimeError: Se VECTOR_STORE_BUCKET não for configurado.
    :return: O índice FAISS carregado do S3.
    :rtype: FAISS
    """
    aws_region = _env("AWS_REGION", "us-east-1")
    bucket = _env("VECTOR_STORE_BUCKET")
    if not bucket:
        raise RuntimeError("VECTOR_STORE_BUCKET não configurado.")

    # Prefixo usado pelo pipeline de ingestão (S3Storage): vector-stores/<db_name>/
    prefix_base = _env("VECTOR_STORE_PREFIX", "vector-stores/")
    if not prefix_base.endswith("/"):
        prefix_base += "/"

    db_name = _env("VECTOR_DB_NAME", "vector_db")
    s3_prefix = f"{prefix_base}{db_name}/"

    # Diretório local para cache do índice
    data_root = Path(_env("DATA_PATH", "/mnt/data"))
    local_dir = data_root / "vectors" / db_name

    _download_s3_prefix(bucket=bucket, prefix=s3_prefix, local_dir=local_dir, region=aws_region)

    embedding_model = _env("EMBEDDING_MODEL", "text-embedding-3-small")
    embeddings = OpenAIEmbeddings(model=embedding_model)

    # Carrega FAISS localmente
    return FAISS.load_local(
        str(local_dir),
        embeddings,
        allow_dangerous_deserialization=True,
    )


def _format_context(docs: List) -> str:
    """
    Formata o contexto de uma lista de documentos em uma string.

    O contexto é formado por uma lista de strings, onde cada string
    representa um documento. Cada string é composta por um
    número, o conteúdo do documento e a fonte do documento.

    Args:
        docs: Lista de documentos a serem formatados.

    Returns:
        Uma string representando o contexto formatado.
    """
 
    lines = []
    for i, doc in enumerate(docs, 1):
        source = (doc.metadata or {}).get("source", "desconhecido")
        page = (doc.metadata or {}).get("page")
        page_info = f" (p. {page})" if page is not None else ""
        lines.append(f"[{i}] {doc.page_content}\nFonte: {source}{page_info}")
    return "\n\n".join(lines)


def _format_sources(docs: List) -> str:
    """
    Formata as fontes de uma lista de documentos em uma string.

    A string é composta por uma lista de strings, onde cada string
    representa uma fonte. Cada string é composta por uma label e a
    fonte do documento.

    Args:
        docs: Lista de documentos a serem formatadas.

    Returns:
        Uma string representando as fontes formatadas.
    """
    seen = set()
    lines = []
    for doc in docs:
        source = (doc.metadata or {}).get("source", "desconhecido")
        page = (doc.metadata or {}).get("page")
        label = f"{source} (p. {page})" if page is not None else source
        if label in seen:
            continue
        seen.add(label)
        lines.append(f"- {label}")
    return "\n".join(lines)


def _format_history(messages: List[dict], max_turns: int) -> str:
    """
    Formata as últimas N mensagens (pares usuário/assistente) em uma string.

    A string é composta por uma lista de strings, onde cada string
    representa uma mensagem. Cada string é composta por uma label e a
    mensagem em si.

    Args:
        messages: Lista de mensagens a serem formatadas.
        max_turns: Número de mensagens a serem consideradas.

    Returns:
        Uma string representando as mensagens formatadas.
    """
    if max_turns <= 0:
        return ""
    # Usa as últimas N mensagens (pares usuário/assistente).
    history = messages[-max_turns * 2 :]
    lines = []
    for msg in history:
        role = "Usuário" if msg["role"] == "user" else "Assistente"
        lines.append(f"{role}: {msg['content']}")
    return "\n".join(lines)


def main() -> None:
    """
    Função principal do script. Responsável por criar a interface do Streamlit e executar a lógica de busca de contexto e resposta do chatbot.

    A interface consiste em um título, um campo de busca, um campo de texto para a pergunta do usuário, uma área de histórico com as mensagens passadas e uma área para a resposta do chatbot.

    A lógica de busca de contexto e resposta é executada assim que o usuário envia uma pergunta. Primeiramente, é carregado o histórico de mensagens passadas e o contexto obtido a partir de uma busca em um vetor de documentos com base no prompt da pergunta.

    Depois, é instanciado um modelo de linguagem grande (LLM) e é gerada uma resposta com base no contexto e no histórico.

    A resposta é, então, formatada com as fontes utilizadas e adicionada ao histórico de mensagens.

    """
    st.set_page_config(page_title="RAG Chat", page_icon="🔎", layout="wide")
    st.title("RAG Chatbot")

    if not _env("OPENAI_API_KEY"):
        st.error("OPENAI_API_KEY não configurado. Verifique SSM/variáveis de ambiente.")
        st.stop()

    with st.sidebar:
        st.header("Configuração")
        k = st.slider("Documentos recuperados (k)", min_value=2, max_value=10, value=4)
        model = st.text_input("Modelo Chat", value=_env("CHAT_MODEL", "gpt-4o-mini") or "gpt-4o-mini")
        history_turns = st.slider(
            "Turnos de histórico",
            min_value=0,
            max_value=6,
            value=3,
            help=(
                "Quantos pares de conversa (usuário + assistente) entram no prompt. "
                "0 = sem histórico; 1 = última pergunta/resposta; 3 = últimas 3."
            ),
        )

    if "messages" not in st.session_state:
        st.session_state.messages = []

    for msg in st.session_state.messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    prompt = st.chat_input("Pergunte sobre os documentos...")
    if not prompt:
        return

    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Buscando contexto..."):
            vectorstore = load_vectorstore()
            retriever = vectorstore.as_retriever(search_kwargs={"k": k})
            docs = retriever.get_relevant_documents(prompt)
            context = _format_context(docs)
            sources = _format_sources(docs)

        llm = ChatOpenAI(model=model)

        # Gerar a resposta
        history_text = _format_history(st.session_state.messages[:-1], history_turns)
        prompt_text = f"""
    Responda à pergunta com base apenas no contexto obtido a seguir e inclua a fonte utilizada como referência ao final.
    Se houver historico da conversa, use apenas para manter coerencia, mas não invente fatos fora do contexto.

    Histórico (se houver):
    {history_text}

    {context}

    Question: {prompt}
    """
        response = llm.invoke(prompt_text)

        answer = response.content if hasattr(response, "content") else str(response)
        if sources:
            answer = f"{answer}\n\n**Fontes**\n{sources}"
        st.markdown(answer)

    st.session_state.messages.append({"role": "assistant", "content": answer})


if __name__ == "__main__":
    main()
