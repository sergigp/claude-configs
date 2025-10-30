---
description: Generate concise Pull Request description from changes
argument-hint: Pull request number
---

Create a brief, developer-focused description of Pull Request changes.

## Process

### 1. Fetch Pull Request Details
Use GitHub CLI commands:
- `gh pr view $ARGUMENTS` - Get PR metadata
- `gh pr diff $ARGUMENTS` - Get code changes

### 2. Generate Description
Create bullet-point summary of main changes:
- Each point should be short and descriptive
- Focus on what changed, not why (developers understand context)
- Balance between detail and brevity

### 3. Description Format
Use bullet points for main changes:
```
- Added user authentication middleware
- Refactored database connection pooling
- Updated error handling in API endpoints
```

## Guidelines

### What to Include
- Key functionality added or modified
- Major refactoring or architectural changes
- Important bug fixes

### What to Avoid
- Explaining basic concepts (audience is developers)
- Too much implementation detail
- Overly vague descriptions
- Too many minor details

### Read-Only Operation
This command performs no write operations to the PR - just generates the description text.

Use GitHub CLI (`gh`) for all GitHub-related operations.
