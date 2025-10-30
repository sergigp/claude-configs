---
description: Execute one iteration from the implementation plan
argument-hint: Task name (directory in .claude/tasks/)
---

Work through plan iterations one at a time, documenting progress in the log.

## Process

### 1. Load Context
Read task files from `.claude/tasks/$ARGUMENTS/`:
- spec.md - Requirements and clarifications
- plan.md or claude_plan_vXX.md - Implementation plan
- log.md - Iteration history (create if doesn't exist)

### 2. Determine Current Iteration
- If log.md doesn't exist: This is iteration 1
- If log.md exists: Find last completed iteration, work on next

### 3. Execute ONE Iteration
Work on the current iteration only:
- Implement the planned changes
- Run tests to verify behavior
- Document progress in log.md

### 4. Update Log
Append to log.md under new section:
```markdown
## Iteration N: [Brief Title]

[Document what was implemented, decisions made, issues found]
```

## Code Style Guidelines

### Comments
- Avoid inline comments
- Use documentation comments (rustdoc for Rust, JSDoc for JS, etc.)
- Prefer clear naming over commenting
- Document functions/services with block comments when needed

### Focus
- ONE iteration per command execution
- Iterative process until plan is fully implemented

## Verification

After each iteration, ensure:
- Tests pass
- Behavior matches specification
- Changes are properly logged

This is an iterative process - run this command repeatedly to work through all planned iterations.
