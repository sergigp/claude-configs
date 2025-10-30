---
description: Create iterative development plan from specification
argument-hint: Task name (directory in .claude/tasks/)
---

Transform specifications into actionable development plans with comprehensive test coverage through iterative planning.

## Process

### 1. Read Specification
- Read spec file: `.claude/tasks/$ARGUMENTS/spec.md`
- Review related files in the same directory (questions.md, log.md, events_spec.json, etc.)

### 2. Generate Plan
- Create plan file: `.claude/tasks/$ARGUMENTS/claude_plan_vXX.md`
- Version number starts at 01, increments with each iteration

### 3. Structure User Stories

Break down specification into manageable work units with:
- **Size**: Implementable in 1-2 hours maximum
- **Deliverable**: Each iteration produces stable, working functionality
- **Testability**: Clear pass/fail criteria
- **Independence**: Minimal dependencies between units

Each iteration should follow this format:

```markdown
## User Stories

### Iteration 1: [Title - Brief Summary]
**Expected Behavior**: [Clear description of deliverable]

**Tests to Implement/Modify**:
- [ ] it_should_validate_user_authentication (new)
- [ ] it_should_handle_invalid_credentials (modify existing)
- [ ] it_should_timeout_after_inactivity (new)

**Implementation Notes**: [Brief technical approach, after tests]
```

## Key Principles

### Testing Approach
- All test names start with "it_should_" focusing on behavior, not implementation
- Prefer modifying existing tests when possible
- Create new tests only when truly needed
- Validate behavior, not implementation details

### Iteration Guidelines
- Target 5-6 iterations maximum
- Each iteration independently deliverable
- Prioritize user-facing functionality early

## Workflow

1. Human edits spec.md with requirements
2. Claude analyzes and generates claude_plan_v01.md
3. Human reviews plan, updates spec.md with clarifications
4. Claude creates claude_plan_v02.md with refinements
5. Repeat until plan is comprehensive and actionable

**Mode**: Switch to plan mode and think carefully before generating the plan.
