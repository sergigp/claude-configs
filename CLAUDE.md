# CLAUDE.md

Personal library of Claude Code commands and skills. Not installed anywhere: files are copied into a project's `.claude/` when needed. See README.md for the layout.

## Structure

- `commands/<group>/<name>.md`: slash commands, invoked as `/<group>:<name>`. Group by topic or language (`pr/`, `code/`, `rust/`).
- `skills/<name>/SKILL.md`: skills, with optional supporting files next to `SKILL.md`.

## Conventions

- Command files start with frontmatter containing `description` and `argument-hint`, then numbered process steps.
- Skill `SKILL.md` frontmatter has `name` and a `description` that says when to trigger it.
- Keep each command/skill self-contained: no references to other files in this repo (templates, scripts), since they're copied individually.
- Language-specific items go under a language folder (`commands/rust/`, `skills/rust-*`).
- When adding, renaming or removing a command or skill, update the layout tree in README.md.
