---
description: Analyze and explain GitHub Pull Request changes
argument-hint: Pull request number
---

Analyze a GitHub Pull Request to understand the problem, changes, and potential issues.

## Process

### 1. Fetch Pull Request Details
Use GitHub CLI commands:
- `gh pr view $ARGUMENTS` - Get PR description and metadata
- `gh pr diff $ARGUMENTS` - Get code changes

### 2. Understand the Problem
- Review PR description for context
- Analyze code changes to infer problem if not explicitly stated

### 3. Explain the Changes
Provide brief, clear explanation of:
- What problem is being solved
- How the changes address the problem
- Key technical decisions made

### 4. Identify Potential Issues
Highlight any concerns:
- Logic errors
- Edge cases not handled
- Performance implications
- Testing gaps
- Code quality issues

## Guidelines

### Analysis Focus
- Understand the "why" behind changes
- Connect code changes to stated objectives
- Look for inconsistencies or gaps

### Read-Only Operation
This command performs no write operations - analysis only.

Use GitHub CLI (`gh`) for all GitHub-related operations.
