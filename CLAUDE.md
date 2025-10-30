# Claude Configuration Repository

Manage Claude Code custom commands, skills and hooks with GNU Stow for easy version control and portability.

## Overview

This repository provides a clean way to manage your Claude Code configurations:

- **Custom Commands**: Shell scripts available in Claude Code
- **Custom Skills**: Specialized knowledge and workflows for Claude

Using GNU Stow, you can:

- Version control all your Claude configurations
- Easily sync across multiple machines
- Quickly enable/disable configurations
- Share with others or backup to GitHub

## Repository Structure

```
claude-config/
├── claude/                    # Stow package
│   └── .claude/              # Mirrors ~/.claude structure
│       ├── commands/         # Custom commands
│       │   ├── example.sh
│       │   └── another.sh
│       └── skills/           # Custom skills
│           ├── my-skill/
│           │   └── SKILL.md
│           └── another-skill/
│               └── SKILL.md
├── README.md
└── setup.sh                  # Optional setup script
```

The `claude` folder is required by Stow - it's the "package" that gets symlinked to your home directory.

## Installation

### Prerequisites

Install GNU Stow:

```bash
brew install stow
```

### Setup

1. Clone this repository:

   ```bash
   git clone <your-repo-url> ~/claude-config
   cd ~/claude-config
   ```

2. Create the directory structure:

   ```bash
   mkdir -p claude/.claude/commands
   mkdir -p claude/.claude/skills
   ```

3. Deploy with Stow:
   ```bash
   stow claude
   ```

That's it! Stow creates symlinks from `~/.claude/` to your repository.

## Usage

### Adding a New Command

1. Create your command script:

   ```bash
   vim claude/.claude/commands/my-command.sh
   ```

2. Add your script content:

   ```bash
   #!/bin/bash
   # Description: What this command does
   echo "Hello from my custom command!"
   ```

3. Make it executable:

   ```bash
   chmod +x claude/.claude/commands/my-command.sh
   ```

4. Commit to Git:
   ```bash
   git add claude/.claude/commands/my-command.sh
   git commit -m "Add my-command"
   ```

### Adding a New Skill

1. Create the skill directory and file:

   ```bash
   mkdir -p claude/.claude/skills/my-skill
   vim claude/.claude/skills/my-skill/SKILL.md
   ```

2. Write your skill documentation:

   ```markdown
   # My Skill

   Description of what this skill provides...

   ## Knowledge

   - Specific domain expertise
   - Best practices
   - Common patterns
   ```

3. Commit to Git:
   ```bash
   git add claude/.claude/skills/my-skill/
   git commit -m "Add my-skill"
   ```

### Managing Your Setup

**Update symlinks** (after adding/removing files):

```bash
cd ~/claude-config
stow -R claude  # Restow (refresh links)
```

**Temporarily disable**:

```bash
cd ~/claude-config
stow -D claude  # Delete symlinks
```

**Re-enable**:

```bash
cd ~/claude-config
stow claude     # Recreate symlinks
```

**Check status**:

```bash
ls -la ~/.claude/
# Should show:
# commands -> ../claude-config/claude/.claude/commands
# skills -> ../claude-config/claude/.claude/skills
```

## Syncing Across Machines

### First Machine (setup)

```bash
cd ~/claude-config
git add .
git commit -m "Update configurations"
git push origin main
```

### Other Machines (sync)

```bash
# Initial setup
git clone <your-repo-url> ~/claude-config
cd ~/claude-config
stow claude

# Later updates
cd ~/claude-config
git pull
stow -R claude  # Refresh symlinks if needed
```

## Examples

### Example Command: `git-recent.sh`

```bash
#!/bin/bash
# claude/.claude/commands/git-recent.sh
# Show recent git commits across all branches

git log --all --oneline --graph --decorate -20
```

### Example Skill: `code-review`

Create `claude/.claude/skills/code-review/SKILL.md`:

```markdown
# Code Review Expert

## Focus Areas

- Security vulnerabilities
- Performance bottlenecks
- Code maintainability
- Test coverage gaps
- Documentation needs

## Review Checklist

1. Does the code follow team conventions?
2. Are edge cases handled?
3. Is error handling appropriate?
4. Are there any obvious bugs?
5. Is the code self-documenting?
```

## Troubleshooting

**"command not found" errors**

- Ensure scripts have shebang: `#!/bin/bash`
- Check execute permissions: `chmod +x claude/.claude/commands/*.sh`

**Symlinks not working**

- Verify Stow installation: `which stow`
- Check for conflicts: `stow -n claude` (dry run)
- Remove and recreate: `stow -D claude && stow claude`

**Skills not loading**

- Each skill needs a `SKILL.md` file
- Check file permissions: `ls -la claude/.claude/skills/`

## Best Practices

1. **Test locally first**: Run commands before committing
2. **Document everything**: Add descriptions to all commands and skills
3. **Use meaningful names**: `format-json.sh` not `fj.sh`
4. **Keep secrets out**: Use environment variables, never hardcode credentials
5. **Regular commits**: Track changes incrementally

## License

[Your chosen license]
