---
description: Integrate answered questions back into specification
argument-hint: Task name (directory in .claude/tasks/)
---

Process answered questions and integrate the clarifications back into the specification.

## Process

### 1. Read Answered Questions
- Read: `.claude/tasks/$ARGUMENTS/questions.md`
- Extract answers provided by human

### 2. Update Specification
- Update: `.claude/tasks/$ARGUMENTS/spec.md`
- Add clarifications to "Key Clarifications and Answered Questions" section
- Review existing section to avoid duplication

### 3. Report Updates
- Summarize what was updated in spec.md
- Share learnings that improve future context understanding

## Guidelines

### What to Update
- Add new clarifications to spec.md
- Integrate domain knowledge from answers
- Preserve context for future iterations

### What NOT to Do
- Don't add new questions (out of scope)
- Don't duplicate existing clarifications
- Don't write code

## Workflow

1. Human answers questions in spec.md
2. Claude reads answers from questions.md
3. Claude updates spec.md with clarifications
4. Claude reports what was learned
5. Iterate as needed

This command focuses solely on integrating answers - use `/spec/iterate` to generate new questions.
