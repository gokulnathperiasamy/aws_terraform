#!/usr/bin/env python3
import sys
import time
import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

collection_endpoint = sys.argv[1]
region              = sys.argv[2]
index_name          = "bedrock-knowledge-base-index"

host = collection_endpoint.replace("https://", "")

# Wait for collection to be ACTIVE
aoss = boto3.client("opensearchserverless", region_name=region)

print("Waiting for AOSS collection to become ACTIVE...")
for _ in range(30):
    resp    = aoss.list_collections(collectionFilters={"status": "ACTIVE"})
    actives = [c for c in resp.get("collectionSummaries", []) if host.startswith(c["id"])]
    if actives:
        print("Collection is ACTIVE")
        break
    print("  still waiting...")
    time.sleep(10)
else:
    print("Collection did not become ACTIVE in time")
    sys.exit(1)

# Extra wait for DNS propagation
print("Waiting 30s for DNS propagation...")
time.sleep(30)

# Build OpenSearch client with SigV4 auth
session = boto3.Session()
creds   = session.get_credentials().get_frozen_credentials()
awsauth = AWS4Auth(creds.access_key, creds.secret_key, region, "aoss", session_token=creds.token)

client = OpenSearch(
    hosts=[{"host": host, "port": 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
    timeout=60,
)

if client.indices.exists(index=index_name):
    print(f"Index '{index_name}' already exists, skipping.")
    sys.exit(0)

body = {
    "settings": {"index.knn": True},
    "mappings": {
        "properties": {
            "bedrock-knowledge-base-default-vector": {
                "type": "knn_vector",
                "dimension": 1024,
                "method": {
                    "name": "hnsw",
                    "engine": "faiss",
                    "space_type": "l2",
                },
            },
            "AMAZON_BEDROCK_TEXT_CHUNK": {"type": "text"},
            "AMAZON_BEDROCK_METADATA":  {"type": "text", "index": False},
        }
    },
}

resp = client.indices.create(index=index_name, body=body)
print(f"Index created: {resp}")
