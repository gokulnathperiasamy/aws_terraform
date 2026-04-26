import os
import json
import boto3

client = boto3.client("bedrock-agent")

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
DATA_SOURCE_ID    = os.environ["DATA_SOURCE_ID"]


def handler(event, context):
    try:
        response = client.start_ingestion_job(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            dataSourceId=DATA_SOURCE_ID,
        )
        job = response["ingestionJob"]
        return _response(200, {"ingestionJobId": job["ingestionJobId"], "status": job["status"]})
    except Exception as e:
        return _response(500, {"error": str(e)})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
