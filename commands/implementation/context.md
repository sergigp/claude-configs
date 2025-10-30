---
description: Load task context before implementation
argument-hint: Task name (directory in .claude/tasks/)
---

Gather and confirm understanding of all task context before beginning implementation work.

## Process

### 1. Read Task Documentation
Load all markdown files from `.claude/tasks/$ARGUMENTS/`:
- spec.md - Functional requirements and specifications
- plan.md or claude_plan_vXX.md - Implementation plan
- questions.md - Clarifications (if exists)
- log.md - Previous iteration notes (if exists)
- Any other relevant documentation

### 2. Confirm Understanding
After reading all context:
- Summarize the task objectives
- Confirm understanding of requirements
- Identify any unclear areas
- Prepare for implementation work

## Purpose

This command ensures full context awareness before starting implementation. Subsequent messages will involve working on the task with complete understanding of:
- What needs to be built
- How it should be implemented
- What has been clarified
- What has been done (if iterating)

**Mode**: Read-only context gathering. No code changes in this command.
