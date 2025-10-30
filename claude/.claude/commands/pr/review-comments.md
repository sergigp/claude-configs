---
description: Analyze and summarize GitHub PR review comments
argument-hint: Pull request number
---

Review unresolved comment threads in a GitHub Pull Request and provide actionable analysis.

## Process

### 1. Fetch Review Comments
Use GitHub CLI to retrieve unresolved comment threads:

```bash
gh api graphql -f query='
  query {
    repository(owner: "coralogix", name: "data-usage") {
      pullRequest(number: $ARGUMENTS) {
        reviewThreads(first: 100) {
          nodes {
            isResolved
            comments(first: 100) {
              nodes {
                id
                author {
                  login
                }
                path
                line
                body
              }
            }
          }
        }
      }
    }
  }
' | jq '.data.repository.pullRequest.reviewThreads.nodes | map(select(.isResolved == false))'
```

### 2. Analyze Each Thread
For each comment thread, provide:
- Brief summary of the comment
- Whether changes are required in this PR
- Technical opinion on the comment's validity
- Proposed code changes (if actionable)

### 3. Output Format

Structure each thread analysis as follows:

```
Thread N:

Title: [Brief title]

Summary: [What the reviewer is saying]

Action Required: [Yes/No - Does this require changes in this PR?]

Technical Opinion: [Your perspective on the comment's validity]

Proposed Changes: [Specific code modifications if actionable]

Path and line: [file.rs:123]
```

## Guidelines

### What to Identify
- Comments requiring code changes
- Comments that are informational only
- Comments about future improvements (not this PR)

### After Analysis
Wait for human to specify which threads to address before making any code changes.

## Configuration

**GitHub Username**: sergigp
**Repository**: Adjust the owner/name in the query as needed

Use GitHub CLI (`gh`) for all GitHub-related operations.
