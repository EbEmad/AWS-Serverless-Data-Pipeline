# AWS Data Pipeline — LocalStack Project

A fully AWS-native data pipeline built and tested locally using **LocalStack**, provisioned with **Terraform**, and implemented in **Python**.

---

##  Architecture

```mermaid
flowchart TD
    EB[/"⏰ EventBridge Scheduler\nCron Trigger"/]

    subgraph Ingestion
        S3_RAW["🪣 S3\nRaw Bucket"]
    end

    subgraph Orchestration
        SF["🔀 Step Functions\nState Machine"]
    end

    subgraph Processing
        L1["λ Lambda\nValidator"]
        L2["λ Lambda\nTransformer"]
    end

    subgraph Storage
        S3_PROC["🪣 S3\nProcessed Bucket"]
        DDB["🗄️ DynamoDB\nTracking Table"]
    end

    subgraph Streaming
        KIN["📡 Kinesis Stream"]
        FH["🔥 Firehose\nDelivery Stream"]
    end

    subgraph Analytics
        OS["🔍 Elasticsearch\nSearch & Analytics"]
        RS["📊 Redshift\nData Warehouse"]
    end

    subgraph Monitoring
        CW["📈 CloudWatch\nMetrics & Logs"]
        SNS["🔔 SNS\nAlerts"]
    end

    EB -->|"Schedules pipeline"| S3_RAW
    S3_RAW -->|"S3 event trigger"| SF
    SF --> L1
    L1 -->|"Valid data"| L2
    L1 -->|"Log result"| DDB
    L2 -->|"Cleaned data"| S3_PROC
    L2 -->|"Stream events"| KIN
    KIN --> FH
    FH -->|"Index documents"| OS
    FH -->|"Load records"| RS
    SF -->|"Execution logs"| CW
    CW -->|"Alarm on failure"| SNS
```
```mermaid
graph LR
    A[Transformer Lambda] -- pushes records --> B[Kinesis Stream]
    B -- flows into --> C[Kinesis Firehose]
    C -- "Auto-delivery" --> D[S3 Archives]
    C -- "Auto-delivery" --> E[Elasticsearch]
    C -- "Auto-delivery" --> F[Redshift]
```
---

##  Tech Stack

| Tool | Purpose |
|---|---|
| **LocalStack** | Emulate all AWS services locally |
| **Terraform** | Infrastructure as Code (IaC) |
| **Python** | Lambda functions & data processing |
| **S3** | Raw and processed data storage |
| **Lambda** | Serverless validation & transformation |
| **Step Functions** | Pipeline orchestration (AWS-native) |
| **Kinesis + Firehose** | Real-time data streaming |
| **Elasticsearch** | Search and analytics |
| **Redshift** | Data warehousing |
| **EventBridge Scheduler** | Cron-based pipeline triggers |
| **CloudWatch** | Monitoring and logging |
| **SNS** | Failure alerts and notifications |
| **DynamoDB** | Pipeline run tracking metadata |

---

##  Project Structure

```
AWS-Data-Pipeline/
├── terraform/
│   ├── main.tf              # Provider + LocalStack config
│   ├── s3.tf                # Raw & processed S3 buckets
│   ├── lambda.tf            # Lambda functions
│   ├── step_functions.tf    # State machine definition
│   ├── kinesis.tf           # Kinesis stream + Firehose
│   ├── dynamodb.tf          # Tracking table
│   ├── elasticsearch.tf     # Elasticsearch domain
│   ├── cloudwatch.tf        # Alarms & dashboards
│   ├── sns.tf               # Alert topics
│   └── variables.tf
│
├── lambdas/
│   ├── validator/
│   │   └── handler.py       # Schema & data quality checks
│   └── transformer/
│       └── handler.py       # Data cleaning & enrichment
│
└── scripts/
    └── seed_data.py         # Push sample data for testing
```

---

##  Getting Started

### Prerequisites
- [LocalStack](https://localstack.cloud/) running locally
- [Terraform](https://www.terraform.io/) installed
- Python 3.9+
- AWS CLI configured with LocalStack profile

### Run Locally

```bash
# Start LocalStack
localstack start

# Deploy infrastructure
cd terraform
terraform init
terraform apply

# Seed test data
python scripts/seed_data.py
```

---

##  Deploy to Real AWS

The same Terraform code deploys to real AWS — simply remove the `endpoints` block and `skip_*` flags from `terraform/main.tf` and configure real AWS credentials.