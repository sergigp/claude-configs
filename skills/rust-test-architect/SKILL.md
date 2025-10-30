---
name: rust-test-architect
description: Generate comprehensive Rust unit/behavior and integration tests following behavior-driven testing patterns. Use when we are designing or refactoring tests in a rust repository.
---

# Rust Test Architect

## File Structure

- `.claude/skills/rust-test-architect/testing-philosophy.md` - Detailed principles and best practices
- `.claude/skills/rust-test-architect/test-patterns.md` - Async patterns, test organization, error handling
- `.claude/skills/rust-test-architect/test-contexts.md` - Complete guide to TestContext setup and usage for infrastructure tests

### Templates

- `.claude/skills/rust-test-architect/templates/behavior-test.rs` - Behavior test template
- `.claude/skills/rust-test-architect/templates/infrastructure-test.rs` - Infrastructure test template

## When to Use This Skill

Use this skill when:

- Writing new tests for features or bug fixes
- Creating integration tests with real services (ClickHouse, PostgreSQL, Kafka, Redis)
- Setting up test fixtures and test data builders
- Implementing behavior tests that test through public APIs
- Creating domain-specific test scenarios (quota overflow, blocking, PAYG, etc.)

## Test Commands

```bash
# Run behaviour tests. This command is super fast and it catches 99% of errors
ut -v
```

## Core Testing Principles

**MANDATORY**: All tests must follow these principles:

1. **Test behavior, not implementation** - Test through public APIs only
2. **Mock at the boundary** - Mock the data access layer, not internal components
3. **Use real services for infrastructure tests** - Via testcontainers
4. **Single responsibility** - Each test verifies one behavior

## Quick Decision Guide

### Choose Test Type

**Behavior Test also known as Unit tests** (most common):

- Testing business logic through service public API
- Mock/stub the repository layer
- Verify observable behavior only
- Location: In source file with `#[cfg(test)]` module

**Infrastructure Test also known as integration tests**:

- Testing actual database queries or storage operations
- Uses real services via testcontainers
- Verifies data persistence and retrieval
- Location: In `/tests/` directory at crate root

## Common Pitfalls to Avoid

1. **Don't test private functions** - Only test through public API
2. **Don't skip cleanup** - TestContext handles this, but be aware
3. **Don't use production configs** - Tests should use test-specific configurations
4. **Don't assert on implementation details** - Focus on observable behavior

## Debugging Test Failures

1. **Use pretty_assertions** for better diff output
2. \*\*Add debug prints with `dbg!()` macro
3. **Check container logs**: `ctx.db.logs()`
4. **Verify test data was inserted**: Query database directly
5. \*\*Use `.expect("descriptive message")` for better error context

## Getting Help

When requesting help with test implementation, provide:

1. What behavior you're testing
2. Whether it's a behavior test or infrastructure test
3. Which services/databases are involved
4. Any domain-specific logic (quota, blocking, PAYG, etc.)

This skill will generate appropriate test structure, contexts, assertions, and test data builders for your specific scenario.
