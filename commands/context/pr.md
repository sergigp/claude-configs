---
description: Load Pull Request context before implementation
argument-hint: Pull request number
---

Gather and confirm understanding of a Pull Request before beginning implementation work.

## Process

### 1. Fetch Pull Request Information

Use GitHub CLI commands to gather PR context:

- `gh pr view $ARGUMENTS` - Get PR title, description, status, and metadata
- `gh pr diff $ARGUMENTS` - Get full code changes

### 2. Analyze PR Content

Review the Pull Request to understand:

- What changes are being proposed
- What problem is being solved
- What files and components are affected
- Current PR status (open, draft, approved, etc.)

### 3. Confirm Understanding

After reading the PR:

- Summarize the PR objectives and changes
- Identify key files and components modified
- Note any related issues or context from PR description
- Identify areas that may need attention or follow-up work
- Prepare for related implementation work

## Purpose

This command ensures full context awareness of a Pull Request before starting related work. Subsequent messages will involve working on code that may:

- Build upon the PR changes
- Fix issues found in the PR
- Add tests for PR functionality
- Refactor code touched by the PR
- Address review comments

**Mode**: Read-only context gathering. No code changes in this command.
