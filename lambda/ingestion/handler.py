import os
import boto3

client = boto3.client("bedrock-agent")

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
DATA_SOURCE_ID = os.environ["DATA_SOURCE_ID"]


def handler(event, context):
    response = client.start_ingestion_job(
        knowledgeBaseId=KNOWLEDGE_BASE_ID,
        dataSourceId=DATA_SOURCE_ID,
    )
    job_id = response["ingestionJob"]["ingestionJobId"]
    print(f"Started ingestion job: {job_id}")
    return {"ingestionJobId": job_id}
