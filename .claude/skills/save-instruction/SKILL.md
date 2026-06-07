---
name: save-instruction
description: Mark the current work as done correctly and capture or refine it as a reusable instruction in the global instruction library. The explicit "Claude got it right" signal. Optionally pass what the instruction should generalize over.
disable-model-invocation: true
argument-hint: "[optional: what to generalize the instruction for]"
allowed-tools: Read Write Edit AskUserQuestion Bash(mkdir *) Bash(printf *) Bash(cat *) Bash(ls *)
---

Global instruction library (absolute path): !`echo "$HOME/.claude/.INSTRUCTIONS"`
Bound slug for this session (empty if none): !`cat "$HOME/.claude/.INSTRUCTIONS/.active/${CLAUDE_SESSION_ID}" 2>/dev/null || true`

Generalization directive (optional): `$ARGUMENTS`

Call that library path **LIB**. The user is confirming this work was done correctly and wants it
captured as a reusable instruction. The optional argument above is **not** a slug — it tells you what
the instruction should generalize over (the axis along which it will be reused). Resolve the target
slug yourself:

## Resolve the slug
- **Bound:** if the bound slug above is non-empty, use it (UPDATE that instruction) automatically —
  the user already declared intent via `/use-instruction`, so don't ask.
- **Unbound — suggest and confirm:** read `LIB/index.md` and compare what this conversation
  accomplished against the existing instructions (skim candidate `LIB/<slug>/MAIN.md` files when a row
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

## Consolidate THIS conversation into `LIB/<slug>/`
Each instruction is a **subfolder** `LIB/<slug>/` holding a `MAIN.md` plus optional detail files.
Create it with `mkdir -p "$HOME/.claude/.INSTRUCTIONS/<slug>"`. If the folder already exists, read its
`MAIN.md` (and any detail files) first, then refine.

`MAIN.md` is the **always-loaded brief**: COMPLETE, CONCISE, GENERALIZED — specific enough to one-shot
the desired result, yet general enough to apply across the cases it's meant for. Getting that balance
right is the whole point of this step.
- **Set the generalization axis.** Decide what should vary between uses (parameterize it) vs. what
  stays fixed:
  - **Directive given:** if `$ARGUMENTS` is non-empty, treat it as the authoritative statement of
    what varies — parameterize exactly that, pin down everything else. Don't ask.
  - **Clear from context:** if `$ARGUMENTS` is empty but a single axis is obviously implied by the
    conversation and the recorded steps, use it and state it in your final report.
  - **Ambiguous → ask:** if there's more than one plausible way to generalize, do NOT guess. Use
    **AskUserQuestion** to present the 2–4 plausible axes as clickable options (the tool adds a
    free-text "Other" automatically) and wait for the user's choice before writing the instruction.
  The goal is an instruction that one-shots the result for every case on its axis without further
  intervention — so resolve this ambiguity now, at save time, rather than leaving it for reuse time.
- Capture the user's true final intent. Where you corrected course mid-conversation, keep the
  CORRECTED instruction and drop the superseded one — this is how an existing instruction absorbs the
  user's new intervention.
- Replace the values that vary along that axis (file names, ids, literals) with `{{named_parameters}}`
  and list them under Parameters; keep everything that should stay constant concrete and explicit.
- Phrase steps as imperative instructions to a future agent, not a narrative of what happened.
- **Keep MAIN.md lean — push depth into detail files.** When the instruction needs extensive material
  (long examples, schemas, command references, edge-case handling, background), put it in a separate
  file in the same subfolder (e.g. `LIB/<slug>/<topic>.md`) and have MAIN.md *reference* it with a
  one-line "read `<topic>.md` when you need X". MAIN.md must stay small enough to load every time;
  details are pulled in only on demand. Don't inline what a reader won't always need.
- If the folder already exists, MERGE into MAIN.md and its detail files — refine and tighten, never
  duplicate; delete detail files that no longer apply.

Template for `MAIN.md`:
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

## Detailed references (read on demand)
- `<topic>.md` — <what's in it and when to read it>   ← omit this whole section if there are none

## Notes / gotchas
- <hard-won constraints only>
```

## Rebuild the index
Rewrite `LIB/index.md` from the front matter of every `<slug>/MAIN.md` (one per instruction subfolder;
ignore the `.active/` folder):

```markdown
# Inferred instruction library

Reusable instructions, shared across all projects. Run `/use-instruction` to reuse one as
the working brief, and `/save-instruction` once Claude has gotten the work right to capture or
refine an instruction here (no command needed to start fresh work — just `/save-instruction` when
done).

| Slug | Use when | Updated |
|------|----------|---------|
| [<slug>](<slug>/MAIN.md) | <when-to-use> | <updated> |
```

Finally, report to the user:
- which slug you created or updated,
- **what changed** — for a new instruction, a one-line description of what was captured; for an
  update, a short bullet list of what you added, revised, or dropped relative to the previous
  version, and
- **the generalization axis** you used — and, if you inferred it (no `$ARGUMENTS`), say so explicitly
  so the user can re-run with a directive if it's wrong.
