import os
import psycopg2


def handler(event, context):
    conn = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ["DB_PORT"]),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        sslmode="require",
    )
    conn.autocommit = True
    cur = conn.cursor()

    cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")

    cur.execute("DROP TABLE IF EXISTS bedrock_kb_vectors;")

    cur.execute("""
        CREATE TABLE bedrock_kb_vectors (
            id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            embedding vector(1024),
            chunks    TEXT,
            metadata  JSON
        );
    """)

    cur.execute("""
        CREATE INDEX bedrock_kb_vectors_embedding_idx
        ON bedrock_kb_vectors
        USING hnsw (embedding vector_cosine_ops);
    """)

    cur.execute("""
        CREATE INDEX bedrock_kb_vectors_chunks_idx
        ON bedrock_kb_vectors
        USING gin (to_tsvector('simple', chunks));
    """)

    cur.close()
    conn.close()
    return {"statusCode": 200, "body": "pgvector setup complete"}
