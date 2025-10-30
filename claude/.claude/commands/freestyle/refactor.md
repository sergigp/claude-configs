---
description: Setup freestyle refactoring session with guidelines
argument-hint: Optional - specific focus area or context
---

Establish guidelines for a freestyle refactoring session focused on improving code structure without changing behavior.

## Session Guidelines

### Primary Objective
Improve implementation without changing behavior - existing tests are the contract.

### Code Style

#### Comments
- **Only allowed**: Documentation comments (rustdoc, JSDoc, etc.)
- **Not allowed**: Inline comments if not asked explicitly
- Prefer clear naming and structure over commentary

### Verification
After each change:
- Run tests
- Ensure all tests pass before proceeding
- Tests validate that behavior is preserved

## Session Mode

This is a **context-gathering command** - no code changes yet.

### What Happens Next
1. This command sets up guidelines
2. Human provides specific refactoring requests
3. Claude implements changes one at a time
4. Tests verify behavior is preserved after each change

## Additional Context

$ARGUMENTS

**Ready**: Guidelines established. Awaiting refactoring instructions.
