# Well-Architected Framework Alignment

How this event-driven e-commerce platform maps to the six pillars of the AWS Well-Architected Framework.

## 1. Operational Excellence

> *How do we run and monitor systems to deliver business value?*

| Practice | Implementation |
|----------|---------------|
| **Observability** | CloudWatch dashboard with Lambda invocations, errors, duration + SQS queue depth + DLQ message count |
| **Alerting** | CloudWatch alarms on every DLQ → SNS email notifications. Zero messages in DLQ is the healthy state |
| **Structured logging** | Lambda functions log order IDs, processing steps, and errors as structured JSON |
| **Infrastructure as Code** | 100% Terraform with reusable modules. No manual resource creation |
| **Small, reversible changes** | Feature branches → develop → main. Each change is a PR with terraform plan |

**Why observability matters in event-driven systems:**
In synchronous architectures, a failed request returns an error to the caller immediately. In event-driven systems, failures are silent — a message sits in a queue, gets retried, and eventually lands in a DLQ. Without observability, you don't know something failed until a customer complains. The dashboard and DLQ alarms close this gap.

## 2. Security

| Practice | Implementation |
|----------|---------------|
| **Least privilege IAM** | Each Lambda has its own role with only the permissions it needs (e.g., order-processor can only PutItem/GetItem/UpdateItem on the orders table) |
| **No hardcoded credentials** | Environment variables for configuration, IAM roles for AWS access |
| **S3 public access blocked** | `aws_s3_bucket_public_access_block` on all buckets |
| **Encryption at rest** | SQS and DynamoDB use AWS-managed encryption by default |

## 3. Reliability

| Practice | Implementation |
|----------|---------------|
| **Fault isolation** | Each consumer has its own SQS queue — a failure in order processing doesn't affect inventory or analytics |
| **Retry with backoff** | SQS visibility timeout + Lambda retry policy handle transient failures automatically |
| **Dead Letter Queues** | After 3 failed attempts, messages go to DLQ instead of being lost. 14-day retention for investigation |
| **DLQ redrive** | Failed messages can be reprocessed after the root cause is fixed |
| **Idempotent processing** | DynamoDB conditional writes prevent duplicate order creation (ADR-006) |
| **No single point of failure** | SNS, SQS, Lambda, DynamoDB, S3 are all managed, multi-AZ services |

## 4. Performance Efficiency

| Practice | Implementation |
|----------|---------------|
| **Right-sized compute** | Lambda at 256MB — sufficient for JSON processing, no over-provisioning |
| **Async processing** | SQS decouples producers from consumers — the API returns immediately, processing happens async |
| **DynamoDB on-demand** | Single-digit ms latency, scales automatically with traffic |
| **Batch processing** | SQS batch size of 10 — Lambda processes multiple messages per invocation, reducing cold starts |
| **Separation of OLTP/OLAP** | DynamoDB for real-time lookups, S3+Athena for analytical queries. Each optimized for its access pattern |

## 5. Cost Optimization

| Practice | Implementation |
|----------|---------------|
| **Pay-per-use everywhere** | Lambda (per invocation), SQS (per message), DynamoDB on-demand (per request), S3 (per GB) |
| **No idle resources** | No EC2 instances, no provisioned capacity. Zero traffic = near-zero cost |
| **Free tier eligible** | Lambda: 1M requests/month free. DynamoDB: 25 WCU/RCU free. SQS: 1M requests free |
| **Environment separation** | Dev environment can be destroyed and recreated with `terraform destroy/apply` — no cost when not in use |

**Estimated cost for demo/low traffic:** < $1/month (within free tier for most services)

## 6. Sustainability

| Practice | Implementation |
|----------|---------------|
| **Serverless-first** | No always-on servers. Compute runs only when there are events to process |
| **Right-sized resources** | Lambda memory tuned to workload. No over-provisioned infrastructure |
| **Managed services** | AWS manages the underlying infrastructure efficiency (multi-tenant, optimized hardware) |

---

## Architecture Alignment Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    Well-Architected Pillar                   │
├──────────────────────┬──────────────────────────────────────┤
│ Operational Excellence│ Dashboard + DLQ alarms + IaC        │
│ Security             │ Least-privilege IAM + encryption     │
│ Reliability          │ SQS buffering + DLQ + idempotency   │
│ Performance          │ Async + DynamoDB + batch processing  │
│ Cost Optimization    │ 100% serverless pay-per-use          │
│ Sustainability       │ No idle compute, right-sized Lambda  │
└──────────────────────┴──────────────────────────────────────┘
```

The event-driven pattern naturally aligns with Well-Architected because:
1. **Decoupling** (SQS) gives you reliability and fault isolation
2. **Serverless** gives you cost optimization and sustainability
3. **Managed services** give you security (encryption, IAM) and performance
4. **Observability** (CloudWatch) closes the gap that async processing creates
