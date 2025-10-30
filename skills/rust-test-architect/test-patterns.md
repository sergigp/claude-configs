# Test Patterns

Common testing patterns used throughout the codebase.

## Async Test Setup

### Basic Async Test

```rust
#[tokio::test]
async fn test_async_operation() {
    let result = async_function().await;
    assert_eq!(result, expected_value);
}
```

### Multi-threaded Async Test

For tests that need multiple threads (e.g., concurrent operations):

```rust
#[tokio::test(flavor = "multi_thread")]
async fn test_concurrent_operations() {
    let handle1 = tokio::spawn(async { process_1().await });
    let handle2 = tokio::spawn(async { process_2().await });

    let (result1, result2) = tokio::join!(handle1, handle2);
    assert!(result1.is_ok());
    assert!(result2.is_ok());
}
```

### Test with Timeout

```rust
#[tokio::test]
async fn test_with_timeout() {
    let result = tokio::time::timeout(
        Duration::from_secs(5),
        slow_operation()
    ).await;

    assert!(result.is_ok(), "Operation timed out");
}
```

## Test Organization Patterns

### Integration Test Structure

```rust
// tests/lib.rs
pub mod common;    // Shared test utilities
pub mod e2e;       // End-to-end tests
pub mod storage;   // Storage-specific tests

// tests/common/mod.rs
pub mod helpers;
pub mod fixtures;

// tests/e2e/blocking_test.rs
use crate::common::helpers::*;

#[test_context(StorageContext)]
#[tokio::test(flavor = "multi_thread")]
async fn test_blocking_workflow(ctx: &mut StorageContext) {
    // Test implementation
}
```

### Unit Test Module Structure

```rust
// src/service/blocker.rs
impl BlockerService {
    pub async fn should_block(&self, context: BlockContext) -> BlockDecision {
        // Implementation
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use pretty_assertions::assert_eq;

    mod should_block {
        use super::*;

        #[tokio::test]
        async fn when_usage_exceeds_quota() {
            // Test case 1
        }

        #[tokio::test]
        async fn when_payg_is_enabled() {
            // Test case 2
        }

        #[tokio::test]
        async fn when_in_trial_period() {
            // Test case 3
        }
    }
}
```

## Mock Patterns

### Repository Mock Pattern

```rust
#[cfg(test)]
mod test {
    use async_trait::async_trait;

    struct MockRepository {
        usage_data: HashMap<CompanyId, f64>,
        quota_data: HashMap<CompanyId, f64>,
    }

    impl MockRepository {
        fn new() -> Self {
            Self {
                usage_data: HashMap::new(),
                quota_data: HashMap::new(),
            }
        }

        fn with_usage(mut self, company_id: CompanyId, usage: f64) -> Self {
            self.usage_data.insert(company_id, usage);
            self
        }

        fn with_quota(mut self, company_id: CompanyId, quota: f64) -> Self {
            self.quota_data.insert(company_id, quota);
            self
        }
    }

    #[async_trait]
    impl Repository for MockRepository {
        async fn get_usage(&self, company_id: CompanyId) -> Result<f64> {
            self.usage_data
                .get(&company_id)
                .copied()
                .ok_or_else(|| anyhow!("No usage data"))
        }

        async fn get_quota(&self, company_id: CompanyId) -> Result<f64> {
            self.quota_data
                .get(&company_id)
                .copied()
                .ok_or_else(|| anyhow!("No quota data"))
        }
    }

    #[tokio::test]
    async fn test_with_mock() {
        let repo = MockRepository::new()
            .with_usage(company_id, 150.0)
            .with_quota(company_id, 100.0);

        let service = BlockerService::new(repo);
        let decision = service.should_block(company_id).await;

        assert!(decision.is_blocked);
    }
}
```

### In-Memory Service Mock

```rust
/// In-memory implementation for testing event publishing
struct InMemoryEventSink {
    events: Arc<Mutex<Vec<Event>>>,
}

impl InMemoryEventSink {
    fn new() -> (Self, Arc<Mutex<Vec<Event>>>) {
        let events = Arc::new(Mutex::new(Vec::new()));
        (Self { events: events.clone() }, events)
    }
}

#[async_trait]
impl EventPublisher for InMemoryEventSink {
    async fn publish(&self, event: Event) -> Result<()> {
        self.events.lock().await.push(event);
        Ok(())
    }
}

#[tokio::test]
async fn test_event_publishing() {
    let (publisher, events) = InMemoryEventSink::new();
    let service = Service::new(publisher);

    service.process_and_publish().await.unwrap();

    let events = events.lock().await;
    assert_eq!(events.len(), 1);
    assert_eq!(events[0].event_type, "expected_type");
}
```

## Error Testing Patterns

### Testing Expected Errors

```rust
#[tokio::test]
async fn test_error_condition() {
    let service = Service::new();

    let result = service.process_invalid_input(-1).await;

    assert!(result.is_err());
    let error = result.unwrap_err();
    assert!(error.to_string().contains("must be positive"));
}
```

### Testing Error Propagation

```rust
#[tokio::test]
async fn test_error_propagation() {
    let mock_repo = MockRepository::new()
        .with_error(anyhow!("Database connection failed"));

    let service = Service::new(mock_repo);
    let result = service.process().await;

    assert!(result.is_err());
    assert!(result
        .unwrap_err()
        .chain()
        .any(|e| e.to_string().contains("Database connection failed")));
}
```

## Assertion Patterns

### Custom Assertion Functions

```rust
fn assert_approximately_equal(actual: f64, expected: f64, tolerance: f64) {
    let diff = (actual - expected).abs();
    assert!(
        diff <= tolerance,
        "Expected {} ± {}, got {}",
        expected, tolerance, actual
    );
}

#[test]
fn test_floating_point_calculation() {
    let result = calculate_percentage(33.0, 100.0);
    assert_approximately_equal(result, 0.33, 0.001);
}
```

### Collection Assertions

```rust
fn assert_contains_all<T: PartialEq + Debug>(
    collection: &[T],
    expected: &[T],
) {
    for item in expected {
        assert!(
            collection.contains(item),
            "Collection does not contain {:?}",
            item
        );
    }
}

#[test]
fn test_collection_contents() {
    let result = process_items();
    let expected = vec!["item1", "item2", "item3"];
    assert_contains_all(&result, &expected);
}
```
