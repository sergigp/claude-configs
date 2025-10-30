# Testing Philosophy

This document outlines the core testing philosophy. These are not just guidelines - they are **mandatory requirements** for all tests.

## Core Principles

### 1. Behavior-Driven Testing

**What it means**: Test observable behavior, not implementation details.

**Why**: Tests should survive refactoring. If you change how something works internally but the behavior remains the same, tests shouldn't break.

**How to apply**:

```rust
// ❌ BAD: Testing internal state
#[test]
fn test_internal_state() {
    let service = Service::new();
    service.process();
    assert_eq!(service.internal_counter, 5); // Don't access private fields
}

// ✅ GOOD: Testing observable behavior
#[test]
fn test_processing_result() {
    let service = Service::new();
    let result = service.process(); // Test through public API
    assert_eq!(result.status, Status::Success);
    assert_eq!(result.items_processed, 5);
}
```

### 2. Test Through Public APIs Only

**What it means**: Only interact with the system under test through its public interface.

**Why**: This ensures you're testing what consumers of your code actually use.

**Practical application**:

- For services: Call public methods
- For gRPC: Use the controller interface
- For domain objects: Use public constructors and methods
- Never use `pub(crate)` or module visibility tricks to access internals for testing

### 3. Mock at the Boundary

**What it means**: Only mock external dependencies (databases, external services), not internal components.

**Layer structure**:

```
Controller (API Layer)
    ↓
Domain (Business Logic)  ← Test this without mocking internals
    ↓
Repository (Data Access) ← Mock this for behavior tests
```

**Example**:

```rust
// Behavior test: Mock the repository
#[tokio::test]
async fn test_blocking_logic() {
    let mock_repo = MockRepository::new()
        .with_usage(company_id, 150.0)
        .with_quota(company_id, 100.0);

    let service = BlockingService::new(mock_repo);
    let decision = service.should_block(company_id).await;

    assert!(decision.blocked);
}

// Infrastructure test: Use real database
#[test_context(StorageContext)]
#[tokio::test(flavor = "multi_thread")]
async fn test_usage_query(ctx: &mut StorageContext) {
    // Insert test data into real ClickHouse
    ctx.conn.insert_usage(company_id, 150.0).await;

    // Test actual query
    let usage = ctx.conn.get_usage(company_id).await;
    assert_eq!(usage, 150.0);
}
```

### 4. Single Responsibility per Test

**What it means**: Each test should verify exactly one behavior.

**Why**: When a test fails, you should immediately know what's broken.

**Pattern**:

```rust
// ❌ BAD: Testing multiple things
#[test]
fn test_user_management() {
    let service = UserService::new();

    // Testing creation
    let user = service.create_user("Alice").unwrap();
    assert_eq!(user.name, "Alice");

    // Testing update in same test
    service.update_user(user.id, "Bob").unwrap();
    let updated = service.get_user(user.id).unwrap();
    assert_eq!(updated.name, "Bob");

    // Testing deletion in same test
    service.delete_user(user.id).unwrap();
    assert!(service.get_user(user.id).is_none());
}

// ✅ GOOD: Separate tests
#[test]
fn test_create_user() {
    let service = UserService::new();
    let user = service.create_user("Alice").unwrap();
    assert_eq!(user.name, "Alice");
}

#[test]
fn test_update_user() {
    let service = UserService::new();
    let user = service.create_user("Alice").unwrap();

    service.update_user(user.id, "Bob").unwrap();
    let updated = service.get_user(user.id).unwrap();

    assert_eq!(updated.name, "Bob");
}

#[test]
fn test_delete_user() {
    let service = UserService::new();
    let user = service.create_user("Alice").unwrap();

    service.delete_user(user.id).unwrap();

    assert!(service.get_user(user.id).is_none());
}
```

## Test Categories

### Behavior Tests (Unit Tests)

**Purpose**: Test business logic in isolation

**Characteristics**:

- Fast execution (milliseconds)
- No external dependencies
- Deterministic
- Located in source files with `#[cfg(test)]`

**When to write**: For all business logic, calculations, state machines, decision trees

### Infrastructure Tests (Integration Tests)

**Purpose**: Verify actual interaction with external systems

**Characteristics**:

- Slower execution (seconds)
- Uses real services via testcontainers
- Tests actual queries, network calls
- Located in `/tests/` directory

**When to write**: For data access layers, complex queries, event publishing

## Test Naming Conventions

### Test Function Names

Use descriptive names that explain the scenario and expected outcome:

```rust
// Pattern 1: it_should_[expected_outcome]
// Pattern 2: it_should_[expected_outcome]_when_[condition]

// For integration tests, can use "it_should" pattern
#[test]
async fn it_should_aggregate_usage_by_entity_type()
#[test]
async fn it_should_publish_event_when_state_changes()
```

### Test Module Organization

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn it_should_aggregate_usage_by_entity_type()

    #[tokio::test]
    async fn it_should_publish_event_when_state_changes()
}
```

## Error Handling in Tests

### Use `.expect()` with Descriptive Messages

```rust
#[test]
async fn it_should_publish_an_event() {
    let event = create_event();

    publisher
        .publish(event)
        .await
        .expect("publishing event should succeed");

    let received = consumer
        .receive()
        .await
        .expect("should receive published event");
}
```

### Test Error Conditions Explicitly

```rust
#[test]
fn it_should_return_an_error_when_quota_is_not_positive() {
    let result = calculate_quota(-100.0);

    assert!(result.is_err());
    assert_eq!(
        result.unwrap_err().to_string(),
        "quota must be positive"
    );
}
```

## Test Data Principles

### Use Factories with Sensible Defaults

```rust
#[cfg(test)]
pub fn test_company() -> Company {
    Company {
        id: unique_company_id(),
        name: "Test Company".to_string(),
        quota: 100.0,
        block_limit: 1.1,
        ..Default::default()
    }
}

#[cfg(test)]
pub fn company_with_payg(overage_factor: f32) -> Company {
    Company {
        payg_enabled: true,
        overage_factor,
        ..test_company()
    }
}
```

### Make Time Deterministic

```rust
use chrono::{TimeZone, Utc};

#[cfg(test)]
fn test_timestamp() -> DateTime<Utc> {
    Utc.ymd(2024, 1, 15).and_hms(12, 0, 0)
}
```

## Performance Considerations for integration/infrastructure Tests

### Container Reuse

**Principle**: Reuse expensive resources (containers) across tests when possible

```rust
use once_cell::sync::Lazy;

static CLICKHOUSE: Lazy<Arc<ClickHouse>> = Lazy::new(|| {
    let container = start_clickhouse();
    run_migrations(&container);
    Arc::new(container)
});
```

## What NOT to Test

### Don't Test the Framework

Don't test that Rust, tokio, or other frameworks work correctly:

```rust
// ❌ BAD: Testing that tokio works
#[tokio::test]
async fn test_async_works() {
    let result = async { 42 }.await;
    assert_eq!(result, 42);
}
```

### Don't Test Simple Getters/Setters

Unless they have business logic:

```rust
// ❌ BAD: Testing trivial getter
#[test]
fn test_get_id() {
    let entity = Entity::new(42);
    assert_eq!(entity.id(), 42);
}

// ✅ GOOD: Testing getter with logic
#[test]
fn test_effective_quota_with_payg() {
    let company = company_with_payg(1.5);
    assert_eq!(company.effective_quota(), 150.0); // base_quota * overage_factor
}
```

## Test Documentation

### Document Complex Scenarios

```rust
/// Test that when an entity with can_overflow=true exceeds its allocation,
/// it can use unallocated quota from the pool. The unallocated quota is
/// distributed proportionally among entities that request it.
///
/// Scenario:
/// - Total quota: 100 units
/// - Logs: 50% allocation, can_overflow=true, using 60 units
/// - Spans: 30% allocation, can_overflow=false, using 25 units
/// - Unallocated: 20%
///
/// Expected: Logs can use 10 units from unallocated pool
#[test]
fn test_overflow_with_unallocated_quota() {
    // Test implementation
}
```

## Assertion Best Practices

### Use `pretty_assertions` for Complex Objects

```rust
use pretty_assertions::assert_eq;

#[test]
fn it_should_whatever() {
    let actual = generate_event();
    let expected = Event {
        event_type: "quota_exceeded",
        company_id: test_company_id(),
        details: EventDetails {
            usage: 150.0,
            quota: 100.0,
            // ... many more fields
        },
    };

    assert_eq!(actual, expected); // pretty_assertions gives nice diffs
}
```

### Create Domain-Specific Assertions

```rust
fn assert_blocked(decision: &BlockingDecision, expected_reason: &str) {
    assert!(decision.blocked, "Expected blocking decision");
    assert_eq!(decision.reason, expected_reason);
    assert!(decision.blocked_at.is_some());
}

#[test]
fn it_should_block_when_exceeding_foc() {
    let decision = blocker.check(context).await;
    assert_blocked(&decision, "exceeded_foc_limit");
}

#[test]
fn it_should_not_block_with_payg() {
    let decision = blocker.check(context).await;
    assert!(!decision.blocked, "Expected not to be blocked");
}
```

## Summary

The key to good tests in this codebase:

1. **Test behavior, not implementation**
2. **Use real services when testing infrastructure**
3. **Mock only at boundaries**
4. **Keep tests isolated and independent**
5. **Make tests deterministic and fast**
6. **Document complex scenarios**
7. **Use the right test type for the job**

Following these principles ensures our tests are:

- **Reliable**: No flaky tests
- **Maintainable**: Survive refactoring
- **Valuable**: Catch real bugs
- **Fast**: Quick feedback loop
- **Clear**: Easy to understand what broke
