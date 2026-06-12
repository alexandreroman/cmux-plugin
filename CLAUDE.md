# CLAUDE.md

Guidance for working in this repository (the cmux Claude Code plugin).

## Project memory

Persist anything that should outlive a single conversation — decisions and
their rationale, workflow preferences, corrective feedback, and external
references — using the `skillbox:project-memory` skill. Invoke it proactively
whenever such information surfaces; you don't need to be asked.

Memory lives in `.claude/project-memory/` at the repo root: an `MEMORY.md`
index plus one file per memory under `references/`. **Always read `MEMORY.md`
at the start of every session, before doing any other work** — it is not
injected automatically, so you must load it yourself. Open the referenced
files under `references/` whenever an index entry looks relevant to the task
at hand (always before writing or updating a skill doc under `skills/`), and
verify a recalled memory against the current code before acting on it. The skill itself is the
source of truth for the exact format and the save/recall/conflict rules —
follow it rather than restating its mechanics here.
