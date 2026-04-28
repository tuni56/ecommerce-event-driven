# E-Commerce Event-Driven Platform on AWS

Real-time and batch processing architecture for e-commerce, built with AWS managed services and Terraform.

> 🎤 Demo project for AWS User Group Arequipa — May 15, 2026

## Architecture Overview

```
                                    ┌─────────────────────────────────┐
                                    │         Real-Time Path          │
                                    │                                 │
                                    │  SQS ──► Lambda ──► DynamoDB   │
                                    │  (order-processing)             │
                                    │                                 │
                                    │  SQS ──► Lambda ──► DynamoDB   │
                  ┌──── Fan-out ───►│  (inventory-update)             │
                  │                 │                                 │
 API Gateway ──► SNS                │  Each queue has a DLQ for       │
 (POST /orders)  (ecommerce-orders) │  failed message handling        │
                  │                 └─────────────────────────────────┘
                  │
                  │                 ┌─────────────────────────────────┐
                  │                 │          Batch Path              │
                  └──── Fan-out ───►│                                 │
                                    │  SQS ──► Lambda ──► S3          │
                                    │  (analytics-ingestion)          │
                                    │                                 │
                                    │  S3 (landing) ──► Glue/Athena   │
                                    └─────────────────────────────────┘
```

Two systems coexist in every e-commerce platform:
- **Real-time path**: processes orders, updates inventory, handles payments — sub-second latency
- **Batch path**: ingests the same events into a data lake for BI, analytics, and ML

SNS fan-out enables **"produce once, consume many"** — a single order event feeds both paths.

## Key Patterns

| Pattern | Implementation | Why |
|---------|---------------|-----|
| Fan-out | SNS → multiple SQS | One event, multiple consumers without coupling |
| Circuit Breaker | SQS buffering + DLQ | Failed service doesn't cascade to others |
| Dead Letter Queue | SQS DLQ + CloudWatch alarm | Capture and alert on poison messages |
| Idempotency | DynamoDB conditional writes | Messages can arrive more than once |
| Retry with backoff | Lambda retry policy + SQS visibility timeout | Transient failures recover automatically |

## Project Structure

```
.
├── terraform/
│   ├── modules/              # Reusable infrastructure modules
│   │   ├── sns/              # SNS topics
│   │   ├── sqs/              # SQS queues + DLQ pairs
│   │   ├── lambda/           # Lambda functions
│   │   ├── dynamodb/         # DynamoDB tables
│   │   ├── s3/               # S3 buckets
│   │   └── monitoring/       # CloudWatch alarms and dashboards
│   └── environments/
│       ├── dev/              # Development environment
│       └── prod/             # Production environment
├── lambdas/                  # Lambda function source code
│   ├── order-processor/
│   ├── inventory-updater/
│   ├── analytics-ingester/
│   └── dlq-handler/
├── scripts/                  # Demo and utility scripts
├── docs/                     # Architecture decisions and diagrams
└── tests/                    # Integration tests
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- Node.js 20+ (for Lambda functions)
- Python 3.12+ (for scripts)

## Quick Start

```bash
# Deploy dev environment
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# Run the demo
cd ../../../scripts
./demo.sh
```

## Branching Strategy

See [docs/BRANCHING_STRATEGY.md](docs/BRANCHING_STRATEGY.md)

## Architecture Decisions

See [docs/ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md)

## License

MIT
