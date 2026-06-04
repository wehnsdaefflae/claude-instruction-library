---
name: save-instruction
description: Mark the current work as done correctly and capture or refine it as a reusable instruction in the global instruction library. The explicit "Claude got it right" signal — takes no argument; the instruction is read from the session binding or generated automatically.
disable-model-invocation: true
allowed-tools: Read Write Edit AskUserQuestion Bash(mkdir *) Bash(printf *) Bash(cat *) Bash(ls *)
---

Global instruction library (absolute path): !`echo "$HOME/.claude/.INSTRUCTIONS"`
Bound slug for this session (empty if none): !`cat "$HOME/.claude/.INSTRUCTIONS/.active/${CLAUDE_SESSION_ID}" 2>/dev/null || true`

Call that library path **LIB**. The user is confirming this work was done correctly and wants it
captured as a reusable instruction. Take **no argument** from the user — resolve the target slug
yourself:

## Resolve the slug
- **Bound:** if the bound slug above is non-empty, use it (UPDATE that instruction) automatically —
  the user already declared intent via `/use-instruction`, so don't ask.
- **Unbound — suggest and confirm:** read `LIB/index.md` and compare what this conversation
  accomplished against the existing instructions (skim candidate `LIB/<slug>.md` files when a row
  looks close). Then **ask the user to choose** (use AskUserQuestion): offer the existing
  instruction(s) that plausibly match as "update `<slug>`" options, plus a "create a new instruction"
  option. Do not decide silently. Wait for their answer.
  - If they pick an existing instruction → UPDATE it.
  - If they pick "create new" → infer a short kebab-case slug from what this conversation
    accomplished, plus a one-line description (the "when to use" documentation).

Once resolved in the unbound case, persist the binding so further `/save-instruction` calls in this
session reuse the slug:
   - `mkdir -p "$HOME/.claude/.INSTRUCTIONS/.active"`
   - `printf '%s\n' '<slug>' > "$HOME/.claude/.INSTRUCTIONS/.active/${CLAUDE_SESSION_ID}"`

## Consolidate THIS conversation into `LIB/<slug>.md`
Read the existing file first if it exists, then write a COMPLETE, CONCISE, GENERALIZED instruction:
- Capture the user's true final intent. Where you corrected course mid-conversation, keep the
  CORRECTED instruction and drop the superseded one — this is how an existing instruction absorbs the
  user's new intervention.
- Replace conversation-specific values (file names, ids, literals) with `{{named_parameters}}` and
  list them under Parameters.
- Phrase steps as imperative instructions to a future agent, not a narrative of what happened.
- If the file already exists, MERGE into its structure — refine and tighten, never append
  duplicates.

Template:
```markdown
---
slug: <kebab-case>
title: <short imperative title>
updated: <YYYY-MM-DD>
---

# <title>

**When to use:** <one line>

## Parameters
- `{{param}}` — <what it is>

## Instructions
1. <imperative step>

## Notes / gotchas
- <hard-won constraints only>
```

## Rebuild the index
Rewrite `LIB/index.md` from the front matter of every `*.md` file **directly in LIB** (ignore the
`.active/` subfolder):

```markdown
# Inferred instruction library

Reusable instructions, shared across all projects. Run `/use-instruction` to reuse one as
the working brief, and `/save-instruction` once Claude has gotten the work right to capture or
refine an instruction here (no command needed to start fresh work — just `/save-instruction` when
done).

| Slug | Use when | Updated |
|------|----------|---------|
| [<slug>](<slug>.md) | <when-to-use> | <updated> |
```

Finally, report to the user:
- which slug you created or updated, and
- **what changed** — for a new instruction, a one-line description of what was captured; for an
  update, a short bullet list of what you added, revised, or dropped relative to the previous version.
