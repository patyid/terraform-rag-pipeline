import argparse
import os
import sys
import tempfile
import zipfile
from pathlib import Path


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="RAG ingestion via rag-pipeline-app (Glue)")
    parser.add_argument("--db-name", default="vector_db", help="Nome do vector DB")
    parser.add_argument("--data-dir", default="data/raw/", help="Prefixo/diretório dos PDFs")
    parser.add_argument("--chunk-size", type=int, default=1000, help="Tamanho dos chunks")
    parser.add_argument("--chunk-overlap", type=int, default=100, help="Sobreposição")
    parser.add_argument("--batch-size", type=int, default=100, help="Tamanho do batch para embeddings")
    parser.add_argument("--pdf-bucket", required=True, help="Bucket S3 para ler PDFs")
    parser.add_argument("--vector-bucket", required=True, help="Bucket S3 para salvar o vectorstore")
    parser.add_argument("--test-query", action="store_true", help="Executa uma consulta de teste ao final")
    # O Glue injeta vários argumentos próprios (ex.: --JOB_NAME). Ignora os desconhecidos.
    args, unknown = parser.parse_known_args()
    if unknown:
        print(f"Ignorando argumentos desconhecidos do Glue: {unknown}", flush=True)
    return args


def _extract_rag_pipeline_app_zip_if_present() -> None:
    zip_path: str | None = None
    for entry in sys.path:
        if entry.endswith("rag-pipeline-app.zip") and os.path.isfile(entry):
            zip_path = entry
            break

    if not zip_path:
        return

    extract_dir = Path(tempfile.gettempdir()) / "rag-pipeline-app-extracted"
    marker_file = extract_dir / ".extracted.ok"

    if not marker_file.exists():
        extract_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(extract_dir)
        marker_file.write_text("ok", encoding="utf-8")

    extract_dir_str = str(extract_dir)
    if extract_dir_str not in sys.path:
        sys.path.insert(0, extract_dir_str)


def main() -> None:
    args = _parse_args()

    _extract_rag_pipeline_app_zip_if_present()
    from src.pipeline import IngestionPipeline

    pipeline = IngestionPipeline(
        data_dir=args.data_dir,
        db_name=args.db_name,
        chunk_size=args.chunk_size,
        chunk_overlap=args.chunk_overlap,
        batch_size=args.batch_size,
        pdf_bucket=args.pdf_bucket,
        vector_bucket=args.vector_bucket,
        save_to_s3=True,
    )

    pipeline.run()

    if args.test_query:
        results = pipeline.query("do que se trata este documento?", k=3)
        for i, doc in enumerate(results, 1):
            print(f"{i}. {doc.page_content[:150]}...")


if __name__ == "__main__":
    main()
