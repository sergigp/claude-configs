# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository provides custom commands and workflows for Claude Code, managed with GNU Stow for version-controlled, portable configuration. It implements a structured software development methodology with distinct phases: specification, planning, implementation, and PR management.

## Stow Management Commands

### Deploy configurations to ~/.claude/
```bash
stow --target=$HOME/.claude .
```

### Update symlinks after changes
```bash
stow --target=$HOME/.claude -R .
```

### Remove symlinks
```bash
stow --target=$HOME/.claude -D .
```

### Preview changes without applying
```bash
stow --target=$HOME/.claude -n -v .
```

## Architecture Overview

The repository mirrors the `~/.claude/` directory structure:

- **agents/**: Subagent definitions for specialized AI assistants (rust-test-architect)
- **commands/**: Slash commands organized by workflow phase (spec, plan, implementation, pr, freestyle)
- **templates/**: Base templates (currently spec.md) for initializing task files
- **skills/**: Custom skills (skill-developer)
- **install-project.sh**: Script to set up .claude/ directories in projects (symlinked to ~/.claude/)
- **.stow-local-ignore**: Keeps README.md and CLAUDE.md in repo, not symlinked

### Task Workspace Pattern

Commands operate on task directories at `.claude/tasks/<task-name>/` containing:
- **spec.md**: Requirements, scope, implementation notes, clarifications
- **plan.md** or **claude_plan_vXX.md**: Versioned implementation plans
- **log.md**: Iteration history tracking implementation progress

Plans are versioned (v01, v02, etc.) when refined. Each iteration appends to log.md with changes and test results.

## Workflow Phases

### 1. Specification Phase (`/spec/*`)
Iteratively refine requirements through clarifying questions:
- `/spec:create <task>` - Bootstrap new task with template
- `/spec:iterate <task>` - Generate clarifying questions
- `/spec:iterate-questions <task>` - Integrate answered questions into spec
- `/spec:plan-refactor <task>` - Create refactoring plan preserving tests

### 2. Planning Phase (`/plan/*`)
Transform specifications into actionable plans:
- `/plan:iterate <task>` - Generate or refine versioned implementation plan with test-driven iterations

### 3. Implementation Phase (`/implementation/*`)
Execute plans iteratively with full context:
- `/implementation:context <task>` - Load all task context (spec, plan, questions, log)
- `/implementation:iterate <task>` - Execute ONE iteration, run tests, update log

**Key Implementation Principles:**
- One iteration per command execution
- Tests must pass before iteration is complete
- Progress documented in log.md after each iteration
- Avoid inline comments; prefer clear naming and block documentation

### 4. Pull Request Tools (`/pr/*`)
Analyze and manage GitHub PRs (requires `gh` CLI):
- `/pr:create-description <number>` - Generate concise PR description from changes
- `/pr:explain <number>` - Analyze what PR does and identify issues
- `/pr:review-comments <number>` - Summarize unresolved review comments

### 5. Freestyle Refactoring (`/freestyle/*`)
Quick refactoring without full spec/plan workflow:
- `/freestyle:refactor [focus-area]` - Setup refactoring session with behavior-preserving guidelines

## Development Patterns

### Adding New Commands
1. Create markdown file in appropriate `commands/` subdirectory
2. Include frontmatter with `description` and `argument-hint`
3. Document the process with numbered steps
4. Run `stow --target=$HOME/.claude -R .` to update symlinks

### Adding New Subagents
1. Create markdown file in `agents/` directory (e.g., `agents/my-agent.md`)
2. Include YAML frontmatter with `name`, `description`, and optionally `model` and `tools`
3. Write comprehensive system prompt that defines the agent's expertise and behavior
4. Run `stow --target=$HOME/.claude -R .` to update symlinks
5. Invoke with "Use the <agent-name> subagent to <task>" or let Claude delegate automatically

### Command File Format
```markdown
---
description: Brief description shown in command list
argument-hint: What the user should provide as argument
---

Command explanation and process steps...
```

### Modifying Templates
Templates in `templates/` are copied (not symlinked) when tasks are initialized. Changes affect only new tasks.

## Requirements

- [Claude Code](https://claude.com/code)
- GNU Stow: `brew install stow`
- GitHub CLI (`gh`): Required for `/pr/*` commands
