---
name: "Skill doc writing style"
description: "How to phrase cmux skill docs — present tense, no version refs, no comparative wording"
type: feedback
---

# Skill doc writing style

When writing or updating any skill under `skills/` (the core `cmux` skill, the
workspace-lifecycle skills, or any plugin documentation), describe the CLI in
the present tense, as it currently is. Do NOT use "now", "used to", "no longer",
"previously", "restored", or similar comparative wording, and do NOT cite
specific cmux version numbers when documenting behavior or options.

**Why:** The docs should read as a timeless description of the current CLI, not
a changelog. Comparative or version-pinned wording rots and confuses agents
reading it later. The skill pins no version by design.

**How to apply:** Even when aligning the docs with a new cmux release, describe
each option as simply available — e.g. "emulation and network controls are
available", not "cmux 0.64.11 exposes…".
