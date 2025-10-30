---
description: Create comprehensive refactoring plan preserving test coverage
argument-hint: Task name (directory in .claude/tasks/)
---

Build an iterative refactoring plan that preserves existing test coverage while improving code structure.

## Process

### 1. Analyze Specification
- Read spec file: `.claude/tasks/$ARGUMENTS/spec.md`
- Generate plan file: `.claude/tasks/$ARGUMENTS/claude_plan_vXX.md`
- Version number starts at 01, increments with each iteration

### 2. Preserve Test Coverage
Existing tests are your safety net - refactor without breaking them.

## Extraction Guidelines

### When to Extract to Private Method
- Logic is only used within the current class
- Operates on the class's internal state/data
- Computational or transformation step with no external dependencies
- Cohesive with the class's primary responsibility
- Simplifies a complex method without changing public interface

### When to Extract to Service
- Has external dependencies (database, API calls, file system)
- Represents a distinct business capability or domain concept
- Logic doesn't directly relate to containing class's core responsibility
- Would improve testability by isolating dependencies

### Naming Conventions
**Good names**: PriceCalculator, EmailValidator, OrderFulfillment, QuotaRulesFinder

**Bad names**: Helper, Utility, Service, Manager

## Iteration Structure

Each iteration should follow this three-step process:

### 1. Extract the Behavior
- Identify behavioral unit to extract based on criteria above
- Create new method/service with descriptive name
- Move code to new location, encapsulating the behavior
- Replace original code with call to extracted method/service
- Pass necessary parameters and handle return values
- Update dependencies and imports

### 2. Verify with Existing Tests
- Run all existing unit tests for modified class
- Ensure all tests still pass (behavior preserved)
- If tests fail, review for:
  - Missing parameters
  - Incorrect return value handling
  - Lost state, context, or broken dependencies

### 3. Add Tests for New Services (Service Extractions Only)
- **Private methods**: No new tests needed (covered by existing tests)
- **Services**: Create dedicated test file covering:
  - Happy path scenarios
  - Edge cases and boundary conditions
  - Error handling
  - All public methods
  - Mock external dependencies
  - Aim for high coverage of extracted logic

## Iteration Requirements

Each iteration must be:
- Independently executable
- Small enough to complete in one session
- Focused on a single behavioral concept

## Workflow

1. Human edits spec.md
2. Claude produces claude_plan_vXX.md (incrementing version)
3. Human improves spec.md with clarifications
4. Repeat until plan is comprehensive

**Mode**: Switch to plan mode and think carefully before generating the plan.
