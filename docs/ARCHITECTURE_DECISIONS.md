# Architecture Decision Records

## ADR-001: SNS Fan-Out over Direct SQS Publishing

**Status:** Accepted

**Context:** Order events need to reach multiple consumers (order processing, inventory, analytics). We could either publish directly to each SQS queue or use SNS as a fan-out layer.

**Decision:** Use SNS as the single entry point, with SQS queues subscribed as consumers.

**Consequences:**
- ✅ Adding a new consumer requires only a new SQS subscription — zero changes to the producer
- ✅ Producer is decoupled from the number and identity of consumers
- ✅ SNS handles fan-out reliability (retries to each subscription independently)
- ⚠️ Adds one extra hop of latency (~ms, negligible)
- ⚠️ SNS message size limit is 256KB (sufficient for order events)

**Alternatives considered:**
- EventBridge: more powerful filtering, but overkill for this use case and higher cost per event
- Direct SQS: simpler but tightly couples producer to consumers

---

## ADR-002: SQS + DLQ as Circuit Breaker

**Status:** Accepted

**Context:** If the order processing Lambda fails (e.g., downstream payment service is down), we need to prevent message loss without blocking the entire pipeline.

**Decision:** Each SQS queue has a paired Dead Letter Queue. After 3 failed processing attempts, messages move to the DLQ. CloudWatch alarms trigger on DLQ message count > 0.

**Consequences:**
- ✅ Failed messages are preserved, not lost
- ✅ Healthy consumers continue processing unaffected
- ✅ DLQ redrive allows reprocessing after the issue is resolved
- ✅ CloudWatch alarms provide immediate visibility
- ⚠️ Messages in DLQ have a retention period (14 days configured) — must be reprocessed before expiry

**Tradeoffs:**
- We chose `maxReceiveCount: 3` as a balance between retry tolerance and fast failure detection. Higher values delay DLQ routing; lower values may send transient failures to DLQ unnecessarily.

---

## ADR-003: DynamoDB over RDS for Order Storage

**Status:** Accepted

**Context:** The real-time path needs sub-10ms writes for order creation and inventory updates.

**Decision:** Use DynamoDB with on-demand capacity for the orders and inventory tables.

**Consequences:**
- ✅ Single-digit millisecond latency at any scale
- ✅ On-demand pricing — no capacity planning needed
- ✅ Native integration with Lambda (event source mapping available for future use)
- ⚠️ No relational joins — analytics queries go through the batch path (S3 + Athena)
- ⚠️ Item size limit of 400KB

**Tradeoffs:**
- We accept the lack of relational queries in the real-time path because analytics is handled by the batch path. This is a deliberate separation of concerns: DynamoDB for OLTP, S3+Athena for OLAP.

---

## ADR-004: Dual-Path Architecture (Real-Time + Batch)

**Status:** Accepted

**Context:** E-commerce platforms need both operational processing (real-time) and analytical processing (batch). These have fundamentally different requirements.

**Decision:** The same SNS event feeds two independent paths:
- Real-time: SQS → Lambda → DynamoDB (operational)
- Batch: SQS → Lambda → S3 (analytical, partitioned by date)

**Consequences:**
- ✅ Each path can scale independently
- ✅ Batch path failure doesn't affect order processing
- ✅ Analytics data lands in S3 in a query-optimized format (JSON partitioned by date)
- ✅ Future: can add Glue for Parquet conversion, Athena for SQL queries
- ⚠️ Eventual consistency between real-time and batch views (seconds to minutes)
- ⚠️ Storage duplication (data exists in both DynamoDB and S3)

**Tradeoffs:**
- The storage duplication is intentional. DynamoDB is optimized for point lookups; S3 is optimized for full scans. Using one for both would compromise performance in one path.

---

## ADR-005: Terraform Modules over Monolithic Configuration

**Status:** Accepted

**Context:** Infrastructure needs to be reproducible across environments (dev/prod) and maintainable as the platform grows.

**Decision:** Each AWS service type is a Terraform module. Environments compose modules with environment-specific variables.

**Consequences:**
- ✅ DRY: queue+DLQ pattern defined once, reused for each consumer
- ✅ Environment parity: dev and prod use the same modules with different parameters
- ✅ Testable: modules can be validated independently
- ⚠️ More files and indirection than a single main.tf
- ⚠️ Module versioning needs discipline as the project grows

---

## ADR-006: Standard SQS over FIFO

**Status:** Accepted

**Context:** SQS offers Standard (at-least-once, best-effort ordering) and FIFO (exactly-once, strict ordering) queue types.

**Decision:** Use Standard queues for all consumers.

**Consequences:**
- ✅ Higher throughput (nearly unlimited vs 3,000 msg/s with batching for FIFO)
- ✅ Lower cost
- ✅ Simpler configuration (no message group IDs)
- ⚠️ Messages may arrive out of order — Lambdas must be idempotent
- ⚠️ Messages may be delivered more than once — handled via conditional writes in DynamoDB

**Tradeoffs:**
- For this e-commerce use case, idempotent processing is simpler and cheaper than FIFO constraints. If strict ordering were critical (e.g., financial ledger), we'd use FIFO with message group IDs per order.
