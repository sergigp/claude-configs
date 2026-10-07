# claude-configs

My personal library of [Claude Code](https://claude.com/code) commands and skills. Nothing is installed automatically: copy what a project needs.

## Layout

```
commands/
├── code/refactor.md          # /code:refactor: behavior-preserving refactor session
├── pr/                       # GitHub PR helpers (need `gh`)
│   ├── context.md            # /pr:context <n>: load PR context before working on it
│   ├── create-description.md # /pr:create-description <n>
│   ├── explain.md            # /pr:explain <n>
│   └── review-comments.md    # /pr:review-comments <n>
└── rust/audit-change.md      # /rust:audit-change: audit an OpenSpec change (needs `openspec`)
skills/
├── rust-architect/           # Rust DDD/hexagonal architecture, naming and testing conventions
└── skill-developer/          # Guide for writing Claude Code skills
```

Folders are grouped by topic or language (`rust/`, `pr/`, ...). A command's folder becomes its prefix: `commands/pr/explain.md` → `/pr:explain`.

## Usage

Copy needed skills and commands per project into `.claude/commands/` and `.claude/skills/` at the project root. Keep it simple.

## Requirements

- [Claude Code](https://claude.com/code)
- `gh` for `pr/*` commands
- `openspec` for `rust/audit-change`
