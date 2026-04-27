#!/usr/bin/env python3
import sys
import psycopg2

DB_ENDPOINT = sys.argv[1]  # format: host:port
DB_PASSWORD = sys.argv[2]
DB_NAME     = "npteldb"
DB_USER     = "npteladmin"

# Split host and port
DB_HOST = DB_ENDPOINT.split(":")[0]
DB_PORT = int(DB_ENDPOINT.split(":")[1]) if ":" in DB_ENDPOINT else 5432

conn = psycopg2.connect(
    host=DB_HOST,
    port=DB_PORT,
    dbname=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD,
    sslmode="require",
)
conn.autocommit = True
cur = conn.cursor()

print("Enabling pgvector extension...")
cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")

print("Creating bedrock_kb_vectors table...")
cur.execute("""
    CREATE TABLE IF NOT EXISTS bedrock_kb_vectors (
        id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        embedding vector(1024),
        chunks    TEXT,
        metadata  TEXT
    );
""")

print("Creating vector index...")
cur.execute("""
    CREATE INDEX IF NOT EXISTS bedrock_kb_vectors_embedding_idx
    ON bedrock_kb_vectors
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
""")

cur.close()
conn.close()
print("Done. RDS pgvector setup complete.")
