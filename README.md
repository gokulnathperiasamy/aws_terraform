# NPTEL IoT Chatbot using AWS Bedrock and Terraform

A Q&A chatbot over 12 weeks of lecture PDFs using a two-step RAG pipeline powered by Amazon Bedrock Knowledge Base, Aurora PostgreSQL (pgvector) and OpenAI GPT OSS 20B on Bedrock.

---

## TL;DR (Quick Start)

**1. Install tools**
```bash
brew install awscli hashicorp/tap/terraform
aws configure   # enter your AWS access key, secret, region: us-east-1
```

**2. Set variables**
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set api_secret_key and db_password
```

**3. Deploy**
```bash
terraform init
terraform apply
```

**4. Update API URL in webpage**
```js
// webpage/index.html
const API_URL = "<api_gateway_invoke_url from terraform output>";
```
```bash
terraform apply   # re-apply to push updated index.html to S3
// If fails to update, delete the instance from Cloud Front and apply again
```

**5. Open the chatbot**
```
https://<website_url from terraform output>
```

> Ingestion runs automatically. Ask questions immediately after deploy.

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
Lambda Authorizer  (public — calls Secrets Manager directly)
 │  validates key against Secrets Manager
 ▼
Query Lambda  (public — calls Bedrock directly) ──────────────────────┐
 │                                                                    │
 │  Step 1: RETRIEVE                          Step 2: GENERATE        │
 │                                                                    │
 ▼                                                                    ▼
Bedrock KB Retrieve API                                   Bedrock InvokeModel
 │  embeds question via Titan Embed v2                   openai.gpt-oss-20b-1:0
 ▼                                                                    │
Aurora PostgreSQL + pgvector  (private VPC)                           │
 │  HNSW cosine similarity search                                     │
 │  returns top 5 matching chunks                                     │
 └──────────── context injected into prompt ──────────────────────────┘
                                                                      │
                                                                      ▼
                                                                 GPT Answer
                                                           (Reasoning & References)
```

---

## RAG Pipeline

### Phase 1 — Indexing (Offline, runs on PDF upload)

```
S3 (raw PDFs)
 └── Bedrock KB Data Source
      └── Titan Embed Text v2  ← chunks PDF text into 512-token segments (20% overlap)
           └── Aurora PostgreSQL (pgvector)  ← stores vectors + raw text chunks
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
 │             └── HNSW cosine similarity search in Aurora pgvector
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
| Vector Store | Aurora PostgreSQL + pgvector | Stores embeddings for semantic search (HNSW index) |
| Embedding Model | Titan Embed Text v2 | Converts text chunks and queries to vectors |
| Generation Model | OpenAI GPT OSS 20B (Bedrock) | Generates answers from retrieved context |
| Knowledge Base | Bedrock Knowledge Base | Manages chunking, embedding, indexing pipeline |
| pgvector Setup | Lambda (pgvector_setup) | Creates vector table + indexes in Aurora on first deploy |
| Ingestion Trigger | Lambda (ingestion) | Starts KB sync on S3 PDF upload |
| Ingest API | Lambda (ingest) | Manually trigger KB sync via GET /ingest |
| Query Handler | Lambda (query) | Runs two-step RAG: Retrieve → Generate |
| Auth | Lambda (authorizer) | Validates x-api-key header via Secrets Manager |
| API | API Gateway | REST endpoint with CORS + header-based auth |
| Secret Storage | Secrets Manager | Stores API key + Aurora DB credentials |
| Networking | VPC + Private Subnets | Isolates Aurora and pgvector_setup Lambda from public internet |
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
│   ├── ingest/handler.py        # Manually triggers Bedrock KB sync via API
│   └── pgvector_setup/
│       ├── handler.py           # Creates pgvector extension, table, HNSW + GIN indexes
│       └── layer/               # psycopg2-binary Lambda layer (Linux x86_64)
├── scripts/
│   └── setup_pgvector.py        # Local pgvector setup script (alternative to Lambda)
├── source_data/                 # Raw lecture PDFs (Week 1–12)
├── webpage/
│   └── index.html               # Chatbot UI — matte black theme, served via CloudFront
└── infra/                       # Terraform module (nptel_chatbot)
    ├── main.tf                  # Provider config, random suffix
    ├── variables.tf             # Module input variables
    ├── outputs.tf               # Module outputs
    ├── vpc.tf                   # VPC, private subnets, security groups (pgvector_setup only)
    ├── s3.tf                    # S3 bucket, PDF uploads, S3 event notification
    ├── s3_website.tf            # S3 bucket for static website + index.html upload
    ├── cloudfront.tf            # CloudFront distribution with OAC
    ├── iam.tf                   # IAM roles and least-privilege policies
    ├── iam_cicd.tf              # IAM roles for CodeBuild, CodePipeline, EventBridge
    ├── rds.tf                   # Aurora Serverless v2 PostgreSQL cluster
    ├── bedrock.tf               # Knowledge Base + S3 data source + chunking config
    ├── secrets.tf               # Secrets Manager for API key + DB credentials
    ├── ssm.tf                   # SSM Parameter Store for terraform.tfvars
    ├── lambda_query.tf          # Query Lambda packaging and deployment
    ├── lambda_authorizer.tf     # Authorizer Lambda packaging and deployment
    ├── lambda_ingestion.tf      # Ingestion Lambda packaging and S3 trigger
    ├── lambda_ingest.tf         # Ingest Lambda packaging and API trigger
    ├── lambda_pgvector_setup.tf # pgvector setup Lambda + psycopg2 layer + auto-invoke
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

### 4. Enable Bedrock Model Access

- `amazon.titan-embed-text-v2:0` used for embedding during indexing and retrieval
- `openai.gpt-oss-20b-1:0` used for answer generation

### 5. Set Up terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region     = "us-east-1"
project_name   = "nptel-qa-iot-2026"
api_secret_key = "your-strong-secret-key"
db_password    = "your-db-password"
```

> `terraform.tfvars` is in `.gitignore` and will never be committed. Use `terraform.tfvars.example` as a reference.

---

## Deploy

```bash
terraform init
terraform apply
```

Terraform will:
1. Create VPC with 2 private subnets (for Aurora + pgvector_setup Lambda only)
2. Create S3 bucket and upload all 12 PDFs from `source_data/`
3. Create Aurora Serverless v2 PostgreSQL cluster
4. Deploy pgvector setup Lambda — creates `bedrock_kb_vectors` table with HNSW + GIN indexes
5. Create Bedrock Knowledge Base pointing to Aurora via RDS Data API
6. Store API key + DB credentials in Secrets Manager
7. Store terraform.tfvars in SSM Parameter Store
8. Deploy 5 Lambda functions — query, authorizer, ingestion, ingest run public; pgvector_setup runs in VPC
9. Create API Gateway REST API with `POST /chat` and `GET /ingest` routes + CORS
10. Create S3 website bucket + CloudFront distribution for the chatbot webpage
11. Create CodeCommit repo, CodePipeline, and EventBridge tag trigger
12. Trigger initial ingestion job automatically

---

## Set Up the Webpage

After `terraform apply`, update the API URL in `webpage/index.html`:

```js
const API_URL = "https://<your-api-uri>.amazonaws.com/v1/chat";
const API_KEY = "NPTEL-2026-IOT-BLR";
```

Then re-apply to push the updated file to S3:

```bash
terraform apply
```

Open the chatbot at the `website_url` from terraform output:
```
https://<your-uri>.cloudfront.net
```


## Trigger Ingestion

Ingestion is triggered automatically by `terraform apply`. To trigger manually:

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
- AWS Console → Amazon Bedrock → Knowledge Bases → nptel-qa-iot-2026-knowledge-base → Sync History

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
api_secret_key = "your-new-secret-key"
db_password = "your-db-password"'
```

Then push a new tag to trigger the pipeline.

### Pipeline IAM Permissions

| Role | Used By | Permissions |
|---|---|---|
| `codebuild-role` | CodeBuild | SSM read, S3 artifacts, full Terraform provisioning |
| `codepipeline-role` | CodePipeline | S3 artifacts, CodeCommit source, CodeBuild trigger |
| `eventbridge-pipeline-role` | EventBridge | `codepipeline:StartPipelineExecution` only |

---

## Cost Estimate

| Service | Original Setup | Current Setup | Saving |
|---|---|---|---|
| Vector Store | OpenSearch Serverless ~$691/month (4 OCU floor, no scale-to-zero) | Aurora pgvector ~$0 idle / ~$14 active | ~$691/month |
| VPC Interface Endpoints | ~$29/month (4 endpoints) | $0 (Lambdas moved out of VPC) | ~$29/month |
| Aurora min_capacity | ~$43/month (0.5 ACU floor) | ~$0 idle (min = 0) | ~$43/month |
| S3 (3 buckets) | ~$0.15/month | ~$0.15/month | — |
| CloudFront | ~$0.01/month | ~$0.01/month | — |
| Lambda (5 functions) | ~$0/month | ~$0/month | — |
| API Gateway | ~$0/month | ~$0/month | — |
| Secrets Manager | ~$0.80/month | ~$0.80/month | — |
| **Total** | **~$763/month** | **~$1-$14/month** | **~$749-$762/month** |

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

> Note: S3 buckets have `force_destroy = true` and Secrets Manager secrets have `recovery_window_in_days = 0` so all resources are cleanly removed.
