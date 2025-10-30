# Test Contexts

Complete guide to using TestContext for managing test fixtures and dependencies in infrastructure tests.

## Overview

TestContext provides automatic setup and teardown of test dependencies using the `test-context` crate. It handles:

- Container lifecycle management
- Database connections
- Migration running
- Cleanup after tests

## Available Test Contexts

### StorageContext (ClickHouse)

**Purpose**: Testing ClickHouse operations and queries

**Location**: `test-utils/src/test_context/clickhouse_context.rs`

**Usage**:

```rust
use test_context::test_context;
use test_utils::test_context::StorageContext;

#[test_context(StorageContext)]
#[tokio::test(flavor = "multi_thread")]
async fn test_usage_aggregation(ctx: &mut StorageContext) {
    // ctx.conn - ClickhouseClient for queries
    // ctx.db - Database config

    // Insert test data
    ctx.conn.execute(
        "INSERT INTO usage_1m (company_id, timestamp, size) VALUES (?, ?, ?)",
        &[&company_id, &timestamp, &size]
    ).await.expect("insert");

    // Query and assert
    let result = ctx.conn.query_row(
        "SELECT SUM(size) FROM usage_1m WHERE company_id = ?",
        &[&company_id]
    ).await.expect("query");

    assert_eq!(result, expected);
}
```

**What it provides**:

- `conn: ClickhouseClient` - Connection to test database
- `db: Database` - Database configuration
- Automatic migration running
- Cleanup on test completion

### PostgresStorageContext

**Purpose**: Testing PostgreSQL operations (quota rules, blocking state)

**Location**: `test-utils/src/test_context/postgres_context.rs`

**Usage**:

```rust
use test_context::test_context;
use test_utils::test_context::PostgresStorageContext;

#[test_context(PostgresStorageContext)]
#[tokio::test(flavor = "multi_thread")]
async fn test_quota_rules(ctx: &mut PostgresStorageContext) {
    // ctx.pool - PostgreSQL connection pool

    let rule = QuotaRule {
        company_id: test_company_id(),
        entity_type: EntityType::Logs,
        allocation: 0.5,
        can_overflow: true,
    };

    sqlx::query!(
        "INSERT INTO quota_rules (company_id, entity_type, allocation, can_overflow)
         VALUES ($1, $2, $3, $4)",
        rule.company_id.0,
        rule.entity_type as i32,
        rule.allocation,
        rule.can_overflow
    )
    .execute(&ctx.pool)
    .await
    .expect("insert rule");

    // Query and verify
    let stored = sqlx::query_as!(
        QuotaRule,
        "SELECT * FROM quota_rules WHERE company_id = $1",
        rule.company_id.0
    )
    .fetch_one(&ctx.pool)
    .await
    .expect("fetch rule");

    assert_eq!(stored.allocation, 0.5);
}
```

**What it provides**:

- `pool: PgPool` - Connection pool to test database
- Migrations automatically applied
- Transaction rollback per test (optional)

### KafkaContext

**Purpose**: Testing event publishing and consumption

**Location**: `test-utils/src/test_context/kafka_context.rs`

**Usage**:

```rust
use test_context::test_context;
use test_utils::test_context::KafkaContext;

#[test_context(KafkaContext)]
#[tokio::test(flavor = "multi_thread")]
async fn test_event_publishing(ctx: &mut KafkaContext) {
    // ctx.producer - Kafka producer
    // ctx.consumer - Kafka consumer
    // ctx.topic - Test topic name

    let event = Event {
        event_type: "quota_exceeded",
        company_id: test_company_id(),
        timestamp: Utc::now(),
    };

    // Publish event
    ctx.producer
        .send(FutureRecord::to(&ctx.topic).payload(&serde_json::to_vec(&event)?))
        .await
        .expect("publish");

    // Consume and verify
    let message = ctx.consumer.recv().await.expect("receive message");
    let received: Event = serde_json::from_slice(message.payload().unwrap())?;

    assert_eq!(received.event_type, "quota_exceeded");
}
```

**What it provides**:

- `producer: FutureProducer` - Kafka producer
- `consumer: StreamConsumer` - Kafka consumer
- `topic: String` - Unique test topic
- Automatic topic creation and cleanup

### RedisContext

**Purpose**: Testing Redis cache operations

**Location**: `test-utils/src/test_context/redis_context.rs`

**Usage**:

```rust
use test_context::test_context;
use test_utils::test_context::RedisContext;

#[test_context(RedisContext)]
#[tokio::test(flavor = "multi_thread")]
async fn test_cache_operations(ctx: &mut RedisContext) {
    // ctx.client - Redis client
    // ctx.conn - Redis connection

    let key = format!("test:company:{}", company_id.0);
    let value = "blocked";

    // Set value
    ctx.conn.set(&key, value).await.expect("set");

    // Get and verify
    let stored: String = ctx.conn.get(&key).await.expect("get");
    assert_eq!(stored, value);

    // Check expiry
    ctx.conn.expire(&key, 60).await.expect("set expiry");

    let ttl: i64 = ctx.conn.ttl(&key).await.expect("get ttl");
    assert!(ttl > 0 && ttl <= 60);
}
```

**What it provides**:

- `client: redis::Client` - Redis client
- `conn: redis::aio::Connection` - Async connection
- Automatic key namespace isolation
- Cleanup of test keys

## Combining Multiple Contexts

When you need multiple services in a test:

```rust
use test_utils::test_context::{StorageContext, KafkaContext};

struct CombinedContext {
    storage: StorageContext,
    kafka: KafkaContext,
}

#[async_trait::async_trait]
impl AsyncTestContext for CombinedContext {
    async fn setup() -> Self {
        Self {
            storage: StorageContext::setup().await,
            kafka: KafkaContext::setup().await,
        }
    }

    async fn teardown(self) {
        self.storage.teardown().await;
        self.kafka.teardown().await;
    }
}

#[test_context(CombinedContext)]
#[tokio::test(flavor = "multi_thread")]
async fn test_with_multiple_services(ctx: &mut CombinedContext) {
    // Insert data into ClickHouse
    ctx.storage.conn.insert(...).await;

    // Publish event to Kafka
    ctx.kafka.producer.send(...).await;

    // Verify both
}
```

## Creating Custom Test Contexts

### Basic Custom Context

```rust
use test_context::AsyncTestContext;
use async_trait::async_trait;

pub struct MyCustomContext {
    pub service: MyService,
    pub test_data: TestData,
}

#[async_trait]
impl AsyncTestContext for MyCustomContext {
    async fn setup() -> Self {
        let service = MyService::new_for_testing().await;
        let test_data = create_test_data().await;

        Self { service, test_data }
    }

    async fn teardown(self) {
        // Cleanup if needed
        self.service.shutdown().await;
    }
}
```

### Context with Container Management

```rust
use testcontainers::{Container, Docker};

pub struct ElasticsearchContext {
    container: Container<'static, ElasticsearchImage>,
    client: ElasticsearchClient,
}

#[async_trait]
impl AsyncTestContext for ElasticsearchContext {
    async fn setup() -> Self {
        let docker = Docker::default();
        let container = docker.run(ElasticsearchImage::default());

        let port = container.get_host_port(9200).unwrap();
        let client = ElasticsearchClient::new(&format!("http://localhost:{}", port));

        // Wait for container to be ready
        wait_for_elasticsearch(&client).await;

        Self { container, client }
    }

    async fn teardown(self) {
        // Container is automatically stopped when dropped
    }
}
```

## Container Lifecycle Management

### Shared Container Pattern

For expensive containers that should be reused:

```rust
use once_cell::sync::Lazy;
use std::sync::Arc;

static SHARED_CLICKHOUSE: Lazy<Arc<ClickHouse>> = Lazy::new(|| {
    Arc::new(create_and_migrate_clickhouse())
});

pub struct StorageContext {
    pub conn: ClickhouseClient,
    _container: Arc<ClickHouse>,
}

#[async_trait]
impl AsyncTestContext for StorageContext {
    async fn setup() -> Self {
        let container = SHARED_CLICKHOUSE.clone();
        let conn = create_client(&*container).await;

        Self {
            conn,
            _container: container,
        }
    }
}
```

### Isolated Container Pattern

For tests that need complete isolation:

```rust
pub struct IsolatedStorageContext {
    container: Container<'static, ClickHouseImage>,
    pub conn: ClickhouseClient,
}

#[async_trait]
impl AsyncTestContext for IsolatedStorageContext {
    async fn setup() -> Self {
        let docker = Docker::default();
        let container = docker.run(ClickHouseImage::default());

        let conn = create_client_for_container(&container).await;
        run_migrations(&conn).await;

        Self { container, conn }
    }

    async fn teardown(self) {
        // Container destroyed with context
    }
}
```

## Migration Management

### Automatic Migration Loading

```rust
async fn run_migrations(conn: &ClickhouseClient) -> Result<()> {
    let migrations = load_migrations(Path::new("migrations/clickhouse"))?;

    for (version, sql) in migrations {
        println!("Running migration {}", version);
        conn.execute(&sql).await?;
    }

    Ok(())
}

pub fn load_migrations(path: &Path) -> Result<Vec<(String, String)>> {
    let mut migrations = Vec::new();

    for entry in std::fs::read_dir(path)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension() == Some("sql".as_ref()) {
            let filename = path.file_name().unwrap().to_str().unwrap();

            // Parse V{number}__{description}.sql format
            if let Some(captures) = MIGRATION_REGEX.captures(filename) {
                let version = captures.get(1).unwrap().as_str().to_string();
                let sql = std::fs::read_to_string(&path)?;
                migrations.push((version, sql));
            }
        }
    }

    // Sort by version number
    migrations.sort_by(|a, b| {
        a.0.parse::<i32>().unwrap()
            .cmp(&b.0.parse::<i32>().unwrap())
    });

    Ok(migrations)
}
```

## Best Practices

### 1. Use Appropriate Context Scope

```rust
// ✅ GOOD: Reuse expensive containers
static CLICKHOUSE: Lazy<Arc<ClickHouse>> = Lazy::new(|| {
    Arc::new(setup_clickhouse())
});

// ❌ BAD: Creating new container for each test (unless isolation needed)
#[test]
async fn test1() {
    let container = start_clickhouse(); // Expensive!
}
```

### 2. Clean Test Isolation

```rust
impl AsyncTestContext for TestContext {
    async fn setup() -> Self {
        let ctx = Self::new();

        // Ensure clean state
        ctx.conn.execute("TRUNCATE TABLE test_data").await.ok();

        ctx
    }
}
```

### 3. Timeout Handling

```rust
async fn wait_for_service(client: &Client) {
    let start = Instant::now();

    loop {
        if client.ping().await.is_ok() {
            break;
        }

        if start.elapsed() > Duration::from_secs(30) {
            panic!("Service failed to start in 30 seconds");
        }

        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}
```

### 4. Parallel Test Support

```rust
pub struct ParallelSafeContext {
    pub conn: Connection,
    test_id: Uuid,
}

impl ParallelSafeContext {
    fn table_name(&self, base: &str) -> String {
        format!("{}_{}", base, self.test_id.to_string().replace('-', "_"))
    }
}

#[test_context(ParallelSafeContext)]
async fn test_parallel_safe(ctx: &mut ParallelSafeContext) {
    let table = ctx.table_name("usage");

    ctx.conn.execute(&format!("CREATE TABLE {} (...)", table)).await;
    // Test with isolated table
}
```

## Troubleshooting

### Container Startup Issues

```rust
// Add detailed logging
#[async_trait]
impl AsyncTestContext for ProblematicContext {
    async fn setup() -> Self {
        println!("Starting container...");
        let container = start_container();

        println!("Container ID: {}", container.id());
        println!("Waiting for readiness...");

        wait_for_ready(&container).await;
        println!("Container ready!");

        // ...
    }
}
```

### Port Binding Issues

```rust
// Use dynamic ports to avoid conflicts
let container = ClickHouseImage::default()
    .with_mapped_port((0, 9000)); // 0 = dynamic port

let port = container.get_host_port(9000).unwrap();
```

### Resource Cleanup

```rust
// Ensure cleanup even on panic
impl Drop for CustomContext {
    fn drop(&mut self) {
        // Cleanup code here
        if let Err(e) = cleanup_resources() {
            eprintln!("Cleanup failed: {}", e);
        }
    }
}
```

## Context Configuration

### Environment-based Configuration

```rust
pub struct ConfigurableContext {
    pub conn: Connection,
}

impl ConfigurableContext {
    async fn setup() -> Self {
        let db_url = std::env::var("TEST_DATABASE_URL")
            .unwrap_or_else(|_| "clickhouse://localhost:9000/test".to_string());

        let conn = Connection::new(&db_url).await;

        Self { conn }
    }
}
```

### Feature Flags

```rust
#[cfg(feature = "integration-tests")]
pub struct IntegrationContext {
    // Real services
}

#[cfg(not(feature = "integration-tests"))]
pub struct IntegrationContext {
    // Mock services
}
```

## Performance Tips

1. **Share expensive resources**: Use `Lazy<Arc<Container>>` for containers
2. **Parallel execution**: Design contexts to support parallel tests
3. **Lazy initialization**: Only create what the test needs
4. **Connection pooling**: Reuse database connections when possible
5. **Batch operations**: Insert test data in batches rather than individually
