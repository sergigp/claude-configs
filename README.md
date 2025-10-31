# Claude Code Custom Commands

A collection of custom commands and workflows for [Claude Code](https://claude.com/code), managed with GNU Stow for easy version control and portability.

## Overview

This repository provides a structured approach to software development using Claude Code, with commands organized into distinct workflows:

- **Specification Management**: Create and refine task specifications with iterative clarification
- **Planning**: Transform specifications into actionable development plans
- **Implementation**: Execute planned iterations with full context awareness
- **Pull Request Tools**: Analyze, explain, and generate PR descriptions
- **Freestyle Refactoring**: Improve code structure while preserving test coverage

## Repository Structure

```
claude-configs/
├── commands/               # Custom commands organized by category
│   ├── freestyle/         # Refactoring commands
│   ├── implementation/    # Implementation workflow commands
│   ├── plan/             # Planning commands
│   ├── pr/               # Pull request tools
│   └── spec/             # Specification management
├── hooks/                 # Hook scripts for project-level configuration
│   ├── skill-activation-prompt.sh
│   ├── skill-activation-prompt.ts
│   └── post-tool-use-tracker.sh
├── skills/                # Custom skills
│   ├── rust-test-architect/
│   └── skill-developer/
├── templates/             # Templates for specs and other files
│   ├── spec.md
│   ├── project-settings.json
│   └── skill-rules.json
├── install-project.sh     # Script to install configs into individual projects
├── .gitignore            # Ignore user-specific settings
├── .stow-local-ignore    # Tell stow to ignore README, CLAUDE.md, etc.
├── CLAUDE.md             # Project-specific Claude Code instructions
└── README.md             # This file
```

The repository structure directly mirrors `~/.claude/`. When you run `stow --target=$HOME/.claude .`, the directories (commands, skills, templates) are symlinked directly into `~/.claude/`. The `.stow-local-ignore` file ensures that README.md and CLAUDE.md stay in the repo and aren't symlinked.

## Installation

### Prerequisites

Install GNU Stow:

```bash
brew install stow
```

### Setup

1. Clone this repository:

   ```bash
   git clone <your-repo-url> ~/claude-configs
   cd ~/claude-configs
   ```

2. Deploy with Stow:

   ```bash
   stow --target=$HOME/.claude .
   ```

This creates symlinks from your repository directly into `~/.claude/`, making all commands available in Claude Code.

### Verify Installation

Check that symlinks are created:

```bash
ls -la ~/.claude/
# Should show symlinks like:
# commands -> ../claude-configs/commands
# templates -> ../claude-configs/templates
```

### Project-Level Configuration

In addition to global configuration at `~/.claude/`, you can install project-specific Claude Code configurations into individual projects. This is useful for:

- **Skill activation hooks** that suggest relevant skills based on your prompts
- **Project-specific settings** like custom permissions or hooks
- **Team-shared configurations** that can be committed to the project repository

#### Installing into a Project

From within any project directory, run:

```bash
/Users/sergigonzalez/dev/personal/claude-configs/install-project.sh
```

Or create an alias in your shell config for convenience:

```bash
alias claude-install='~/dev/personal/claude-configs/install-project.sh'
```

Then from any project:

```bash
claude-install
```

#### What Gets Installed

The script creates a `.claude/` directory in your project with:

- **`.claude/settings.json`** - Project-level settings with hooks configured to use project-local scripts
- **`.claude/hooks/`** - Hook scripts that run before/after Claude Code operations
  - `skill-activation-prompt.sh` + `.ts` - Suggests relevant skills based on your prompts
  - `post-tool-use-tracker.sh` - Tracks file edits for build automation
- **`.claude/skills/skill-rules.json`** - Configuration for which skills activate on which keywords/patterns

#### Customizing Project Configs

After installation, you can customize the project's `.claude/skills/skill-rules.json` to add project-specific skill activation rules:

```json
{
  "version": "1.0",
  "skills": {
    "rust-test-architect": {
      "type": "domain",
      "enforcement": "suggest",
      "priority": "high",
      "promptTriggers": {
        "keywords": ["test", "testing"],
        "intentPatterns": ["write.*test", "add.*test"]
      }
    }
  }
}
```

#### Sharing Configs with Your Team

You can choose to:

- **Personal configs**: Add `.claude/` to your project's `.gitignore` to keep configs local
- **Team configs**: Commit `.claude/` to share hooks and skill activation rules with your team

## Command Reference

### Specification Management

- **`/spec/create <task-name>`** - Bootstrap a new task with spec template in `.claude/tasks/<task-name>/`
- **`/spec/iterate <task-name>`** - Generate clarifying questions to refine the specification
- **`/spec/iterate-questions <task-name>`** - Integrate answered questions back into the spec
- **`/spec/plan-refactor <task-name>`** - Create versioned refactoring plan preserving test coverage

### Planning

- **`/plan/iterate <task-name>`** - Transform spec into actionable development plan with test-driven iterations

### Implementation

- **`/implementation/context <task-name>`** - Load all task context (spec, plan, questions, log) before starting work
- **`/implementation/iterate <task-name>`** - Execute one iteration from the plan, run tests, and update log

### Pull Request Tools

- **`/pr/create-description <pr-number>`** - Generate concise PR description from code changes
- **`/pr/explain <pr-number>`** - Analyze and explain what a PR does and identify potential issues
- **`/pr/review-comments <pr-number>`** - Summarize unresolved PR review comments with actionable analysis

### Freestyle Refactoring

- **`/freestyle/refactor [focus-area]`** - Setup refactoring session with behavior-preserving guidelines

---

## Typical Workflows

### New Feature Development

1. **Create specification:**
   ```bash
   /spec/create my-feature
   ```

2. **Refine through questions:**
   ```bash
   /spec/iterate my-feature
   # Answer questions in spec.md
   /spec/iterate-questions my-feature
   ```

3. **Generate implementation plan:**
   ```bash
   /plan/iterate my-feature
   # Review plan, refine spec if needed
   /plan/iterate my-feature  # v02
   ```

4. **Implement iteratively:**
   ```bash
   /implementation/context my-feature
   /implementation/iterate my-feature  # Iteration 1
   /implementation/iterate my-feature  # Iteration 2
   # ... continue until complete
   ```

### Refactoring Existing Code

1. **Create refactoring spec:**
   ```bash
   /spec/create refactor-payment-flow
   # Document what needs refactoring and why
   ```

2. **Generate refactoring plan:**
   ```bash
   /spec/plan-refactor refactor-payment-flow
   ```

3. **Execute refactoring:**
   ```bash
   /implementation/context refactor-payment-flow
   /implementation/iterate refactor-payment-flow
   ```

**OR for quick refactoring:**
```bash
/freestyle/refactor payment processing
# Then provide specific requests
```

### Pull Request Review

1. **Understand the changes:**
   ```bash
   /pr/explain 123
   ```

2. **Review comments:**
   ```bash
   /pr/review-comments 123
   # Analyze which need addressing
   ```

3. **Generate description:**
   ```bash
   /pr/create-description 123
   ```

---

## Managing Your Setup

### Update symlinks (after adding/removing files)

```bash
cd ~/claude-configs
stow --target=$HOME/.claude -R .  # Restow (refresh links)
```

### Temporarily disable

```bash
cd ~/claude-configs
stow --target=$HOME/.claude -D .  # Delete symlinks
```

### Re-enable

```bash
cd ~/claude-configs
stow --target=$HOME/.claude .  # Recreate symlinks
```

### Sync across machines

**First machine:**
```bash
cd ~/claude-configs
git add .
git commit -m "Update configurations"
git push
```

**Other machines:**
```bash
cd ~/claude-configs
git pull
stow --target=$HOME/.claude -R .  # Refresh symlinks
```

---

## Best Practices

1. **Iterative refinement**: Specifications and plans improve through iteration
2. **Test-driven**: Tests validate behavior throughout development and refactoring
3. **Small iterations**: Each iteration should be completable in 1-2 hours
4. **Documentation**: Keep specs, plans, and logs up to date
5. **Version control**: Commit task files alongside code changes

---

## Requirements

- [Claude Code](https://claude.com/code)
- GNU Stow (`brew install stow`)
- GitHub CLI (`gh`) for PR-related commands

---

## License

MIT
