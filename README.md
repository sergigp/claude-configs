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
├── rust/audit-change.md      # /rust:audit-change: audit an OpenSpec change (needs `openspec`)
└── typescript/audit-change.md # /typescript:audit-change: same for TypeScript (needs `openspec`, StrykerJS)
skills/
├── rust-architect/           # Rust DDD/hexagonal architecture, naming and testing conventions
├── skill-developer/          # Guide for writing Claude Code skills
└── typescript-architect/     # TypeScript DDD/hexagonal architecture, naming and testing conventions
```

Folders are grouped by topic or language (`rust/`, `pr/`, ...). A command's folder becomes its prefix: `commands/pr/explain.md` → `/pr:explain`.

## Usage

Copy needed skills and commands per project into `.claude/commands/` and `.claude/skills/` at the project root. Keep it simple.

## Requirements

- [Claude Code](https://claude.com/code)
- `gh` for `pr/*` commands
- `openspec` for `rust/audit-change` and `typescript/audit-change`
- [StrykerJS](https://stryker-mutator.io) (`@stryker-mutator/core` + test runner plugin) in the target project for `typescript/audit-change`
