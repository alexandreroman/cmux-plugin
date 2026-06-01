# CLAUDE.md

Guidance for working in this repository (the cmux Claude Code plugin).

## Writing skill and command docs

When writing or updating the skill (`skills/cmux/`), slash commands
(`commands/`), or any plugin documentation, describe the CLI in the **present
tense, as it currently is**:

- Do **not** use "now", "used to", "no longer", "previously", "restored", or
  similar comparative wording.
- Do **not** cite specific cmux version numbers when documenting behavior or
  options. The skill pins no version by design — keep it that way.
- Even when aligning the docs with a new cmux release, describe each option as
  simply available — e.g. "emulation and network controls are available", not
  "cmux 0.64.11 exposes…".

The docs should read as a timeless description of the current CLI, not a
changelog. Comparative or version-pinned wording rots and confuses agents
reading it later.
