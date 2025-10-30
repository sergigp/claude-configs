---
description: Generate clarifying questions for specification refinement
argument-hint: Task name (directory in .claude/tasks/)
---

Help refine specifications by identifying ambiguities and generating clarifying questions.

## Process

### 1. Analyze Specification
- Read spec file: `.claude/tasks/$ARGUMENTS/spec.md`
- Identify ambiguities in functional requirements and user stories

### 2. Generate Questions
- Create or replace: `.claude/tasks/$ARGUMENTS/questions.md`
- Focus on functional requirements and behavior
- Skip questions already answered in spec.md

## Question Format

Structure questions following this template:

```markdown
# Questions:

## Section 1: [Title of the section]

### Question 1: [Your question here]
* context of the question
* question
* answer: [left blank for human to fill]
```

## Guidelines

### What to Ask About
- Functional requirements and behavior
- User stories and expected outcomes
- Ambiguities in the specification

### What NOT to Ask About
- Alerting or monitoring (out of scope)
- Performance considerations (out of scope)
- Questions already answered in spec.md

### When to Skip
If everything is clear from the spec.md file, it's acceptable to have no questions or notes.

## Workflow

1. Human edits spec.md
2. Claude generates questions.md with clarifying questions
3. Human updates spec.md answering questions in "Key Clarifications and Answered Questions" section
4. Human triggers this command again to iterate

**Mode**: Switch to plan mode. No code writing - only planning and question generation.
