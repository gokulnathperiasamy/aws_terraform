# NPTEL IoT Chatbot — AWS Bedrock + Terraform

A Q&A chatbot over 12 weeks of lecture PDFs using a two-step RAG pipeline powered by Amazon Bedrock Knowledge Base, OpenSearch Serverless, and OpenAI GPT OSS 20B on Bedrock.

---

## Architecture

```
Browser (CloudFront → S3 static webpage)
 │
 │  POST /chat     → ask a question
 │  GET  /ingest   → trigger PDF ingestion
 │  header: x-api-key
 ▼
API Gateway
 │
 ▼
Lambda Authorizer
 │  validates key against Secrets Manager
 ▼
Query Lambda  ──────────────────────────────────────────────────────┐
 │                                                                   │
 │  Step 1: RETRIEVE                          Step 2: GENERATE       │
 │                                                                   │
 ▼                                                                   ▼
Bedrock KB Retrieve API                          Bedrock InvokeModel
 │  embeds question via Titan Embed v2            openai.gpt-oss-20b-1:0
 ▼                                                 │
OpenSearch Serverless (vector search)              │
 │  returns top 5 matching chunks                  │
 └──────────── context injected into prompt ───────┘
                                                   │
                                                   ▼
                                 Answer + Reasoning + References
```

All Lambda functions run inside a private VPC with VPC endpoints — no internet gateway required.

---

## RAG Pipeline

RAG (Retrieval-Augmented Generation) is the core of this chatbot. It has two phases:

### Phase 1 — Indexing (Offline, runs on PDF upload)

```
S3 (raw PDFs)
 └── Bedrock KB Data Source
      └── Titan Embed Text v2  ← chunks PDF text into 512-token segments (20% overlap)
           └── OpenSearch Serverless  ← stores vectors + raw text chunks
```

- Triggered automatically when a PDF is uploaded to S3
- S3 event → `ingestion` Lambda → `bedrock-agent:StartIngestionJob`
- Also triggerable manually via `GET /ingest` API endpoint
- Bedrock handles chunking, embedding, and indexing automatically

### Phase 2 — Query (Online, per user request)

```
User question
 │
 ├─ Step 1: RETRIEVE
 │   └── Bedrock KB Retrieve API
 │        └── Titan Embed Text v2 embeds the question into a vector
 │             └── Cosine similarity search in OpenSearch Serverless
 │                  └── Returns top 5 most relevant text chunks + source metadata
 │
 └─ Step 2: GENERATE
      └── Retrieved chunks injected into prompt as context
           └── openai.gpt-oss-20b-1:0 (via Bedrock InvokeModel)
                └── Generates answer + reasoning + source citations (Week X)
```

---

## Infrastructure Components

| Component | AWS Service | Purpose |
|---|---|---|
| PDF Storage | S3 | Stores raw lecture PDFs |
| Vector Store | OpenSearch Serverless | Stores embeddings for semantic search |
| Embedding Model | Titan Embed Text v2 | Converts text chunks and queries to vectors |
| Generation Model | OpenAI GPT OSS 20B (Bedrock) | Generates answers from retrieved context |
| Knowledge Base | Bedrock Knowledge Base | Manages chunking, embedding, indexing pipeline |
| Ingestion Trigger | Lambda (ingestion) | Starts KB sync on S3 PDF upload |
| Ingest API | Lambda (ingest) | Manually trigger KB sync via GET /ingest |
| Query Handler | Lambda (query) | Runs two-step RAG: Retrieve → Generate |
| Auth | Lambda (authorizer) | Validates x-api-key header via Secrets Manager |
| API | API Gateway | REST endpoint with CORS + header-based auth |
| Secret Storage | Secrets Manager | Stores API secret key |
| Networking | VPC + Private Subnets | Isolates all Lambdas from public internet |
| VPC Endpoints | Interface + Gateway | Private access to S3, Bedrock, Secrets Manager |
| Static Website | S3 + CloudFront | Hosts the chatbot webpage over HTTPS |

---

## Project Structure

```
AWS_Terraform/                   ← root (run terraform apply here)
├── main.tf                      # Calls module nptel_chatbot from ./infra
├── variables.tf                 # Root input variables
├── outputs.tf                   # Proxies module outputs
├── terraform.tfvars             # Variable values (never commit this)
├── terraform.tfvars.example     # Reference template for terraform.tfvars
├── lambda/                      # Lambda source code
│   ├── query/handler.py         # Two-step RAG: Retrieve + InvokeModel + reasoning extraction
│   ├── authorizer/handler.py    # Validates x-api-key against Secrets Manager
│   ├── ingestion/handler.py     # Triggers Bedrock KB sync on S3 upload
│   └── ingest/handler.py        # Manually triggers Bedrock KB sync via API
├── scripts/
│   └── create_aoss_index.py     # Creates OpenSearch vector index before KB creation
├── source_data/                 # Raw lecture PDFs (Week 1–12)
├── webpage/
│   └── index.html               # Chatbot UI — matte black theme, served via CloudFront
└── infra/                       # Terraform module (nptel_chatbot)
    ├── main.tf                  # Provider config, random suffix
    ├── variables.tf             # Module input variables
    ├── outputs.tf               # Module outputs
    ├── vpc.tf                   # VPC, private subnets, security groups, VPC endpoints
    ├── s3.tf                    # S3 bucket, PDF uploads, S3 event notification
    ├── s3_website.tf            # S3 bucket for static website + index.html upload
    ├── cloudfront.tf            # CloudFront distribution with OAC
    ├── iam.tf                   # IAM roles and least-privilege policies
    ├── iam_cicd.tf              # IAM roles for CodeBuild, CodePipeline, EventBridge
    ├── opensearch.tf            # AOSS collection, security/access policies
    ├── bedrock.tf               # Knowledge Base + S3 data source + chunking config
    ├── secrets.tf               # Secrets Manager secret for API key
    ├── ssm.tf                   # SSM Parameter Store for terraform.tfvars
    ├── lambda_query.tf          # Query Lambda packaging and deployment
    ├── lambda_authorizer.tf     # Authorizer Lambda packaging and deployment
    ├── lambda_ingestion.tf      # Ingestion Lambda packaging and S3 trigger
    ├── lambda_ingest.tf         # Ingest Lambda packaging and API trigger
    ├── api_gateway.tf           # REST API, REQUEST authorizer, CORS, routes, stage
    ├── codecommit.tf            # CodeCommit repository
    ├── codepipeline.tf          # CodePipeline, CodeBuild, EventBridge rule
    └── buildspec.yml            # CodeBuild instructions
```

---

## Prerequisites

### 1. Install Terraform

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform -version
```

> Download for other OS: https://developer.hashicorp.com/terraform/install

### 2. Install AWS CLI

```bash
# macOS
brew install awscli
aws --version
```

> Download for other OS: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

### 3. Configure AWS Credentials

```bash
aws configure
```

You will be prompted for:
```
AWS Access Key ID:     <your-access-key-id>
AWS Secret Access Key: <your-secret-access-key>
Default region name:   us-east-1
Default output format: json
```

> Get your credentials from: AWS Console → IAM → Users → your user → Security credentials → Create access key

### 4. Install Python Packages

Required locally for the OpenSearch index creation script that runs during `terraform apply`:

```bash
pip install opensearch-py boto3 requests-aws4auth
```

### 5. Enable Bedrock Model Access

- Go to: https://console.aws.amazon.com/bedrock/home#/modelaccess
- Click **Modify model access**
- Enable both models:
  - `amazon.titan-embed-text-v2:0` — used for embedding during indexing and retrieval
  - `openai.gpt-oss-20b-1:0` — used for answer generation
- Click **Save changes**

### 6. Set Up terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set `api_secret_key` to a strong secret of your choice — this is the key callers must pass in the `x-api-key` header to use the API:

```hcl
aws_region     = "us-east-1"
project_name   = "nptel-qa-iot-2026"
api_secret_key = "your-strong-secret-key"
```

> `terraform.tfvars` is in `.gitignore` and will never be committed. Use `terraform.tfvars.example` as a reference.

---

## Deploy

```bash
terraform init
terraform apply
```

Terraform will:
1. Create VPC with 2 private subnets and 5 VPC endpoints
2. Create S3 bucket and upload all 12 PDFs from `source_data/`
3. Create OpenSearch Serverless vector collection + vector index
4. Create Bedrock Knowledge Base pointing to S3 with fixed-size chunking
5. Store API secret key in Secrets Manager
6. Store terraform.tfvars in SSM Parameter Store
7. Deploy 4 Lambda functions (query, authorizer, ingestion, ingest) inside the VPC
8. Create API Gateway REST API with `POST /chat` and `GET /ingest` routes + CORS
9. Create S3 website bucket + CloudFront distribution for the chatbot webpage
10. Create CodeCommit repo, CodePipeline, and EventBridge tag trigger

---

## Set Up the Webpage

After `terraform apply`, update the API URL in `webpage/index.html`:

```js
const API_URL = "https://i3arb3ey53.execute-api.us-east-1.amazonaws.com/v1/chat";
const API_KEY = "NPTEL-2026-IOT-BLR";
```

Then re-apply to push the updated file to S3:

```bash
terraform apply
```

Open the chatbot at the `website_url` from terraform output:
```
https://djx27qfo8femv.cloudfront.net
```

### Webpage Features

- Matte black theme (`#1a1a1a` background)
- Textarea input with 12px rounded corners
- `Find Answer` — primary button (grey background, black text)
- `Reset` — secondary button (grey border, grey text) — clears the entire page
- Answer displayed in a focused card with white text
- Reasoning shown as italic muted grey subtext below the answer
- References rendered as cards at the bottom with source name + excerpt
- `Ctrl+Enter` keyboard shortcut to submit

---

## Trigger Ingestion

After `terraform apply`, trigger the initial ingestion to embed and index all PDFs:

```bash
curl -X GET <api_gateway_ingest_url from terraform output> \
  -H "x-api-key: NPTEL-2026-IOT-BLR"
```

### Example Response

```json
{
  "ingestionJobId": "abc123xyz",
  "status": "STARTING"
}
```

Ingestion takes a few minutes. Check status in:
- AWS Console → Amazon Bedrock → Knowledge Bases → nptel-qa-iot-2026-kb → Sync History

---

## Query the Chatbot

```bash
curl -X POST <api_gateway_invoke_url from terraform output> \
  -H "x-api-key: NPTEL-2026-IOT-BLR" \
  -H "Content-Type: application/json" \
  -d '{"question": "What topics are covered in Week 3?"}'
```

### Example Response

```json
{
  "answer": "Week 3 covers database normalization including 1NF, 2NF, and 3NF as discussed in the Week 3 Lecture Material...",
  "reasoning": "The context from Week 3 Course Material clearly describes normalization concepts...",
  "references": [
    {
      "source": "Week 3 Course Material",
      "excerpt": "Database normalization is the process of organizing a relational database..."
    },
    {
      "source": "Week 2 Lecture Material",
      "excerpt": "Entity-relationship diagrams form the foundation for understanding..."
    }
  ]
}
```

---

## Authentication

All requests must include the `x-api-key` header. The value must match `api_secret_key` in `terraform.tfvars`.

- API Gateway passes the header to the Lambda authorizer
- The authorizer fetches the secret from Secrets Manager (cached in-memory per Lambda instance)
- Returns `Allow` or `Deny` IAM policy scoped to all routes (`/*/*`)
- Authorized requests are forwarded to the respective Lambda

---

## Adding New PDFs

1. Drop new PDFs into `source_data/`
2. Run `terraform apply` — Terraform uploads them to S3
3. The S3 event triggers the ingestion Lambda automatically
4. Or call `GET /ingest` to trigger manually

---

## CI/CD Pipeline

### Overview

```
git tag deploy-changes-v1.0
git push origin deploy-changes-v1.0
        │
        ▼
EventBridge Rule
  matches tag pattern: deploy-changes-*
        │
        ▼
CodePipeline
  ├── Source  → pulls tagged commit from CodeCommit
  └── Deploy  → CodeBuild runs terraform init + plan + apply
```

### How It Works

- **CodeCommit** hosts the repository with all Terraform files and Lambda source code
- **EventBridge** watches for `referenceCreated` events on tags matching `deploy-changes-*`
- **CodePipeline** is triggered by EventBridge — it pulls the source at the tagged commit
- **CodeBuild** fetches `terraform.tfvars` from SSM Parameter Store (SecureString), then runs:
  ```
  terraform init
  terraform validate
  terraform plan
  terraform apply -auto-approve
  ```
- `terraform.tfvars` is **never committed** — it lives in SSM Parameter Store at `/nptel-qa-iot-2026/tfvars`

### Push Code to CodeCommit

After the first `terraform apply`, push the code to CodeCommit:

```bash
git init
git remote add origin <codecommit_clone_url_http from terraform output>
git add .
git commit -m "initial commit"
git push origin main
```

> For CodeCommit HTTP authentication, use [git-remote-codecommit](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-git-remote-codecommit.html):
> ```bash
> pip install git-remote-codecommit
> git remote set-url origin codecommit::us-east-1://nptel-qa-iot-2026
> ```

### Trigger a Deployment

```bash
git tag deploy-changes-v1.0
git push origin deploy-changes-v1.0
```

The tag must start with `deploy-changes-` — any suffix works (e.g. `deploy-changes-v2.0`, `deploy-changes-hotfix-1`).

### Update terraform.tfvars in SSM

If you need to change variable values (e.g. rotate the API key):

```bash
aws ssm put-parameter \
  --name "/nptel-qa-iot-2026/tfvars" \
  --type SecureString \
  --overwrite \
  --value 'aws_region = "us-east-1"
project_name = "nptel-qa-iot-2026"
api_secret_key = "your-new-secret-key"'
```

Then push a new tag to trigger the pipeline.

### Pipeline IAM Permissions

| Role | Used By | Permissions |
|---|---|---|
| `codebuild-role` | CodeBuild | SSM read, S3 artifacts, full Terraform provisioning |
| `codepipeline-role` | CodePipeline | S3 artifacts, CodeCommit source, CodeBuild trigger |
| `eventbridge-pipeline-role` | EventBridge | `codepipeline:StartPipelineExecution` only |

---

## State Files

| File | Purpose |
|---|---|
| `terraform.tfstate` | Current state of all provisioned resources |
| `terraform.tfstate.backup` | Previous state — automatic backup before each apply |

Both are excluded from git via `.gitignore` — they contain sensitive resource IDs and ARNs.

---

## Destroy

```bash
terraform destroy
```

> Note: S3 buckets have `force_destroy = true` and Secrets Manager secret has `recovery_window_in_days = 0` so all resources are cleanly removed.
