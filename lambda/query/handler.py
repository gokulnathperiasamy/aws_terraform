import json
import os
import re
import boto3

bedrock_agent_runtime = boto3.client("bedrock-agent-runtime")
bedrock_runtime       = boto3.client("bedrock-runtime")

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
MODEL_ID          = os.environ["MODEL_ID"]


def handler(event, context):
    try:
        body     = json.loads(event.get("body") or "{}")
        question = body.get("question", "").strip()

        if not question:
            return _response(400, {"error": "Missing 'question' in request body"})

        # Step 1: Retrieve relevant chunks from Knowledge Base
        retrieve_response = bedrock_agent_runtime.retrieve(
            knowledgeBaseId=KNOWLEDGE_BASE_ID,
            retrievalQuery={"text": question},
            retrievalConfiguration={
                "vectorSearchConfiguration": {"numberOfResults": 5}
            },
        )

        results                = retrieve_response.get("retrievalResults", [])
        context_text, references = _build_context(results)

        # Step 2: Generate answer using OpenAI GPT OSS 20B via InvokeModel
        prompt = _build_prompt(question, context_text)

        model_response = bedrock_runtime.invoke_model(
            modelId=MODEL_ID,
            contentType="application/json",
            accept="application/json",
            body=json.dumps({
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 1024,
                "temperature": 0.2,
            }),
        )

        response_body = json.loads(model_response["body"].read())
        full_text     = response_body["choices"][0]["message"]["content"]

        answer, reasoning = _extract_reasoning(full_text)

        return _response(200, {
            "answer":     answer.strip(),
            "reasoning":  reasoning.strip(),
            "references": references,
        })

    except Exception as e:
        return _response(500, {"error": str(e)})


def _extract_reasoning(text):
    match = re.search(r"<reasoning>(.*?)</reasoning>", text, re.DOTALL)
    if match:
        reasoning = match.group(1).strip()
        answer    = re.sub(r"<reasoning>.*?</reasoning>", "", text, flags=re.DOTALL).strip()
    else:
        reasoning = ""
        answer    = text
    return answer, reasoning


def _build_context(results):
    context_parts = []
    references    = []
    seen_sources  = set()

    for i, result in enumerate(results, 1):
        text   = result.get("content", {}).get("text", "")
        uri    = result.get("location", {}).get("s3Location", {}).get("uri", "")
        source = uri.split("/")[-1].replace(".pdf", "") if uri else "Unknown"

        context_parts.append(f"[{i}] {text}")

        if source not in seen_sources:
            seen_sources.add(source)
            references.append({"source": source, "excerpt": text[:200]})

    return "\n\n".join(context_parts), references


def _build_prompt(question, context_text):
    return (
        "You are a helpful assistant answering questions based on lecture materials.\n"
        "First, write your reasoning inside <reasoning>...</reasoning> tags.\n"
        "Then write the final answer clearly outside the tags.\n"
        "Always cite the source document (e.g. 'Week 3 Lecture Material') and mention the chapter or section when relevant.\n"
        "If the answer is not in the context, say you don't know.\n\n"
        f"Context:\n{context_text}\n\n"
        f"Question: {question}\n\n"
        "Response:"
    )


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
