# Module 10: Application Architecture — Exercises

## Exercise 1: Send a Test Event to Event Grid and Verify Delivery
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Publish a custom event to an Event Grid topic and verify that a subscriber receives it, demonstrating the event-driven messaging pattern.

### Instructions
1. List Event Grid topics in the resource group:
   ```bash
   az eventgrid topic list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. Get the topic endpoint and access key:
   ```bash
   az eventgrid topic show \
     --name <topic-name> \
     --resource-group rg-az305-lab \
     --query "{endpoint: endpoint}" --output json
   ```
   ```bash
   az eventgrid topic key list \
     --name <topic-name> \
     --resource-group rg-az305-lab \
     --query "key1" --output tsv
   ```
3. List event subscriptions on the topic:
   ```bash
   az eventgrid event-subscription list \
     --source-resource-id "/subscriptions/<sub-id>/resourceGroups/rg-az305-lab/providers/Microsoft.EventGrid/topics/<topic-name>" \
     --output table
   ```
4. Send a test event:
   ```bash
   TOPIC_ENDPOINT=$(az eventgrid topic show --name <topic-name> --resource-group rg-az305-lab --query "endpoint" --output tsv)
   TOPIC_KEY=$(az eventgrid topic key list --name <topic-name> --resource-group rg-az305-lab --query "key1" --output tsv)

   curl -X POST "$TOPIC_ENDPOINT" \
     -H "aeg-sas-key: $TOPIC_KEY" \
     -H "Content-Type: application/json" \
     -d '[{"id": "test-1", "eventType": "Lab.TestEvent", "subject": "az305/exercise", "eventTime": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "data": {"message": "Hello from AZ-305 lab!"}, "dataVersion": "1.0"}]'
   ```
5. Check the subscriber (webhook, Function, queue) to verify delivery.

### Success Criteria
- The event is published to the topic successfully (HTTP 200).
- The subscriber receives the event.
- You understand the Event Grid schema: id, eventType, subject, data, eventTime.

### Explanation
Event Grid is the event routing service in Azure. AZ-305 tests when to use Event Grid vs. Event Hubs vs. Service Bus. Event Grid: reactive programming, event routing, push-based delivery, at-least-once delivery. It connects Azure services (resource events) and custom applications. The exam tests scenarios like "notify when a blob is uploaded" (Event Grid system topic) or "route custom business events to multiple subscribers" (Event Grid custom topic).

---

## Exercise 2: Send a Message to Service Bus Queue and Receive It
**Difficulty:** 🟢 Guided
**Method:** CLI
**Estimated Time:** 10 minutes

### Objective
Send and receive messages through an Azure Service Bus queue to understand reliable messaging patterns.

### Instructions
1. List Service Bus namespaces:
   ```bash
   az servicebus namespace list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. List queues in the namespace:
   ```bash
   az servicebus queue list \
     --namespace-name <namespace-name> \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, MaxSize:maxSizeInMegabytes, MessageCount:messageCount}"
   ```
3. Send a message to the queue:
   ```bash
   az servicebus queue send \
     --namespace-name <namespace-name> \
     --resource-group rg-az305-lab \
     --queue-name <queue-name> \
     --body "AZ-305 Lab Test Message - $(date)"
   ```
4. Peek at messages (view without removing):
   ```bash
   az servicebus queue peek \
     --namespace-name <namespace-name> \
     --resource-group rg-az305-lab \
     --queue-name <queue-name> \
     --output json | jq '.[0] | {body, enqueuedTime, sequenceNumber}'
   ```
5. Receive and delete a message:
   ```bash
   az servicebus queue receive \
     --namespace-name <namespace-name> \
     --resource-group rg-az305-lab \
     --queue-name <queue-name> \
     --output json
   ```

### Success Criteria
- You can send a message to the queue and verify it arrived.
- You understand peek (non-destructive read) vs. receive (destructive read).
- You know that Service Bus provides guaranteed delivery (messages persist until consumed).

### Explanation
Service Bus is the enterprise messaging service in Azure. AZ-305 tests Service Bus for: guaranteed message delivery, FIFO ordering (sessions), transactions, dead-letter queues, and scheduled delivery. The exam contrasts Service Bus queues (point-to-point) with Service Bus topics/subscriptions (publish-subscribe). Key exam fact: Service Bus Premium tier supports 1 MB messages (Standard: 256 KB) and provides dedicated resources for predictable performance.

---

## Exercise 3: Configure an Event Hub Consumer and Process Events
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 20 minutes

### Objective
Send events to an Event Hub and consume them, understanding the high-throughput event ingestion pattern.

### Instructions
1. List Event Hub namespaces and hubs:
   ```bash
   az eventhubs namespace list \
     --resource-group rg-az305-lab \
     --output table
   ```
   ```bash
   az eventhubs eventhub list \
     --namespace-name <namespace-name> \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, PartitionCount:partitionCount, MessageRetention:messageRetentionInDays}"
   ```
2. View consumer groups:
   ```bash
   az eventhubs eventhub consumer-group list \
     --namespace-name <namespace-name> \
     --resource-group rg-az305-lab \
     --eventhub-name <hub-name> \
     --output table
   ```
3. Send test events (using the connection string):
   ```bash
   # Get the connection string
   az eventhubs namespace authorization-rule keys list \
     --namespace-name <namespace-name> \
     --resource-group rg-az305-lab \
     --name RootManageSharedAccessKey \
     --query "primaryConnectionString" --output tsv
   ```
4. View partition information:
   ```bash
   az eventhubs eventhub show \
     --namespace-name <namespace-name> \
     --resource-group rg-az305-lab \
     --name <hub-name> \
     --output json | jq '{partitionCount, partitionIds: .partitionIds, status}'
   ```
5. Understand the consumer group model: each consumer group maintains its own offset per partition.

### Success Criteria
- You can send events to the Event Hub.
- You understand partitions and their role in parallelism.
- You know that consumer groups allow multiple independent readers of the same stream.

### Explanation
Event Hubs is for high-throughput event streaming (millions of events per second). AZ-305 tests Event Hubs for: telemetry ingestion, log aggregation, and real-time analytics. Key difference from Service Bus: Event Hubs uses a pull model (consumers read at their own pace), retains events for a configurable period (1-90 days), and scales via partitions. The exam tests partition count selection: more partitions = more parallelism but higher cost.

---

## Exercise 4: Create an API in API Management with Rate Limiting
**Difficulty:** 🟡 Intermediate
**Method:** CLI / Portal
**Estimated Time:** 25 minutes

### Objective
Configure an API in Azure API Management with rate limiting policies to protect backend services from overload.

### Instructions
1. List API Management instances:
   ```bash
   az apim list \
     --resource-group rg-az305-lab \
     --output table
   ```
2. List APIs in the APIM instance:
   ```bash
   az apim api list \
     --resource-group rg-az305-lab \
     --service-name <apim-name> \
     --output table
   ```
3. View an API's operations:
   ```bash
   az apim api operation list \
     --resource-group rg-az305-lab \
     --service-name <apim-name> \
     --api-id <api-id> \
     --output table
   ```
4. In the Portal, add a rate-limit policy to the API:
   ```xml
   <inbound>
     <rate-limit calls="10" renewal-period="60" />
     <base />
   </inbound>
   ```
   This limits to 10 calls per minute per subscription key.
5. Test the rate limit by making rapid requests:
   ```bash
   for i in $(seq 1 15); do
     echo "Request $i: $(curl -s -o /dev/null -w '%{http_code}' -H 'Ocp-Apim-Subscription-Key: <key>' https://<apim-name>.azure-api.net/<api-path>)"
   done
   ```
6. After exceeding the limit, observe the HTTP 429 (Too Many Requests) response.

### Success Criteria
- You can list APIs and their operations in APIM.
- The rate-limit policy is applied and enforced.
- Requests beyond the limit receive HTTP 429.
- You understand the difference between rate-limit (fixed window) and rate-limit-by-key (per caller).

### Explanation
API Management is tested on AZ-305 as the API gateway solution. Key policies: rate limiting (protect backends), caching (reduce backend load), authentication (validate JWT tokens), transformation (modify request/response). The exam tests tier selection: Consumption (serverless, low cost, no VNet), Developer (non-production), Basic/Standard (production), Premium (multi-region, VNet integration). The exam also tests APIM as the entry point for microservices architectures.

---

## Exercise 5: Write and Read from Redis Cache
**Difficulty:** 🟡 Intermediate
**Method:** CLI
**Estimated Time:** 15 minutes

### Objective
Interact with Azure Cache for Redis to understand caching patterns and performance characteristics.

### Instructions
1. List Redis Cache instances:
   ```bash
   az redis list \
     --resource-group rg-az305-lab \
     --output table \
     --query "[].{Name:name, SKU:sku.name, Tier:sku.family, Port:port}"
   ```
2. Get connection details:
   ```bash
   az redis show \
     --name <redis-name> \
     --resource-group rg-az305-lab \
     --output json | jq '{hostName, sslPort, enableNonSslPort, minimumTlsVersion}'
   ```
3. Get the access key:
   ```bash
   az redis list-keys \
     --name <redis-name> \
     --resource-group rg-az305-lab \
     --query "primaryKey" --output tsv
   ```
4. Connect using redis-cli (if available) or use the Console in the Portal:
   ```bash
   redis-cli -h <hostname> -p 6380 --tls -a <access-key>
   ```
5. Set and get values:
   ```
   SET session:user123 '{"name":"John","cart":["item1","item2"]}'
   GET session:user123
   TTL session:user123
   EXPIRE session:user123 3600
   ```
6. Test cache performance by comparing cached vs. uncached response times.

### Success Criteria
- You can connect to Redis and perform basic operations (SET, GET, EXPIRE).
- You understand TTL (time-to-live) and its role in cache invalidation.
- You know the Redis Cache tiers: Basic (no SLA), Standard (replicated), Premium (clustering, persistence, VNet).

### Explanation
Redis Cache is tested on AZ-305 for session state, output caching, and data caching. The exam tests the cache-aside pattern: application checks cache first, on miss reads from database and populates cache. Key design decisions: eviction policies (LRU is default), persistence (RDB snapshots, AOF logs), and clustering for large datasets. The exam also tests when NOT to cache: frequently updated data with low read-to-write ratio, or data where staleness is unacceptable.

---

## Exercise 6: Design an Event-Driven Architecture for E-Commerce
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 30 minutes

### Objective
Design an event-driven architecture for an e-commerce platform that handles order processing, inventory updates, payment processing, and notifications.

### Instructions
Design the architecture addressing:

1. **Order processing:**
   - Customer places an order through the API.
   - The order must be processed reliably (no lost orders).
   - Processing involves: validate inventory, charge payment, update inventory, send confirmation.
   - Which messaging service ensures reliable, ordered processing? (Service Bus)

2. **Inventory updates:**
   - Multiple services need to know when inventory changes.
   - Publish-subscribe pattern: which service? (Service Bus Topics or Event Grid)
   - How do you ensure each subscriber gets the update?

3. **Payment processing:**
   - Payment must be processed exactly once.
   - How do you handle the "dual write" problem (update database AND send message)?
   - What is the Outbox pattern and when to use it?
   - How do you handle payment failures (compensation/saga pattern)?

4. **Notifications:**
   - Fan-out to multiple channels: email, SMS, push notification.
   - Event Grid for routing to different handlers?
   - Azure Functions for processing each notification type?

5. **Telemetry and analytics:**
   - Track all user actions (page views, clicks, purchases).
   - Millions of events per hour during peak.
   - Which service handles this scale? (Event Hubs)
   - How do you process this for real-time dashboards? (Stream Analytics)

6. **Error handling:**
   - Dead-letter queues for failed messages.
   - Retry policies with exponential backoff.
   - Circuit breaker pattern for downstream service failures.
   - How do you monitor and alert on processing failures?

### Success Criteria
- Service Bus is used for order processing (guaranteed delivery, FIFO).
- Event Grid or Service Bus Topics are used for publish-subscribe scenarios.
- Event Hubs is used for high-volume telemetry ingestion.
- Dead-letter queues handle poison messages.
- The design follows the saga pattern for distributed transactions.

### Explanation
This tests the AZ-305 messaging service selection matrix. The exam expects you to know: Service Bus = enterprise messaging (transactions, ordering, guaranteed delivery). Event Grid = event routing (reactive, push-based, at-least-once). Event Hubs = big data streaming (millions/sec, retention, replay). Storage Queues = simple queuing (cheap, large volume, no ordering guarantee). The exam also tests patterns: saga for distributed transactions, outbox for reliable messaging, and CQRS for read/write separation.

---

## Exercise 7: Select Messaging Services for Complex Requirements
**Difficulty:** 🔴 Challenge
**Method:** Conceptual
**Estimated Time:** 25 minutes

### Objective
**Scenario:** A system needs to: (1) process customer orders with guaranteed delivery and strict ordering, (2) send notifications to multiple channels when an order status changes (fan-out), and (3) ingest telemetry from 100,000 IoT devices sending data every 5 seconds (millions of events per second).

Select the appropriate messaging service for each requirement and justify your choice.

### Instructions

**Requirement 1: Order Processing**
- Needs: guaranteed delivery, FIFO ordering, exactly-once processing, dead-letter for failures.
- Evaluate: Service Bus Queue, Storage Queue, Event Grid.
- Consider: Service Bus sessions for ordered processing per order ID.
- Answer: Which service and why?

**Requirement 2: Order Status Notifications**
- Needs: fan-out to email service, SMS service, and mobile push service.
- Each subscriber processes independently.
- Evaluate: Service Bus Topics, Event Grid, Event Hubs.
- Consider: filtering (not all subscribers need all events).
- Answer: Which service and why?

**Requirement 3: IoT Telemetry Ingestion**
- Needs: millions of events per second, retention for replay, low latency.
- Multiple consumers process the stream independently (real-time analytics, storage, ML).
- Evaluate: Event Hubs, Service Bus, IoT Hub.
- Consider: partition strategy for parallelism.
- Answer: Which service and why?

Create a comparison matrix:

| Feature | Service Bus | Event Grid | Event Hubs | Storage Queue |
|---|---|---|---|---|
| Delivery | At-least-once, exactly-once | At-least-once | At-least-once | At-least-once |
| Ordering | FIFO (sessions) | No guarantee | Per partition | No guarantee |
| Throughput | Moderate | High | Very high | Moderate |
| Retention | Until consumed | 24h retry | 1-90 days | 7 days |
| Pattern | Command/Queue | Event routing | Stream | Simple queue |
| Cost | Higher | Per event | Per TU/CU | Lowest |

### Success Criteria
- Order processing uses Service Bus Queue with sessions for FIFO ordering.
- Notifications use Service Bus Topics (for filtering) or Event Grid (for push-based fan-out).
- IoT telemetry uses Event Hubs (or IoT Hub with Event Hubs endpoint).
- Each choice is justified with specific feature requirements.
- The comparison matrix is accurate and complete.

### Explanation
This is one of the most frequently tested AZ-305 topics. The exam presents a scenario and expects you to select the right messaging service. The decision tree: Need guaranteed delivery + ordering? Service Bus. Need event routing with push delivery? Event Grid. Need high-throughput streaming with retention? Event Hubs. Need simple, cheap queuing? Storage Queue. Need IoT device management + telemetry? IoT Hub (built on Event Hubs). The exam penalizes over-engineering (using Event Hubs for 10 messages/hour) and under-engineering (using Storage Queue for ordering requirements).
