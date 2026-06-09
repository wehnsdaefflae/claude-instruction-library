---
name: save-instruction
description: Mark the current work as done correctly and capture or refine it as a reusable instruction in the global instruction library. The explicit "Claude got it right" signal. Optionally pass what the instruction should generalize over.
disable-model-invocation: true
argument-hint: "[optional: what to generalize the instruction for]"
allowed-tools: Read Write Edit AskUserQuestion Bash(echo *) Bash(cat *) Bash(head *) Bash(mkdir *) Bash(printf *) Bash(find *) Bash(git *) Bash(ls *) Bash(wc *)
---

Global instruction library (absolute path): !`echo "$HOME/.claude/.INSTRUCTIONS"`
Bound slug for this session (empty if none): !`cat "$HOME/.claude/.INSTRUCTIONS/.active/${CLAUDE_SESSION_ID}" 2>/dev/null || true`
Catalog — derived live from each instruction's front matter; there is **no stored index**:
!`head -n 6 "$HOME"/.claude/.INSTRUCTIONS/*/MAIN.md 2>/dev/null || true`

Generalization directive (optional): `$ARGUMENTS`

Call that library path **LIB**. The user is confirming this work was done correctly and wants it
captured as a reusable instruction. The optional argument above is **not** a slug — it tells you what
the instruction should generalize over (the axis along which it will be reused). Resolve the target
slug yourself:

## Resolve the slug
- **Bound:** if the bound slug above is non-empty, use it (UPDATE that instruction) automatically —
  the user already declared intent via `/use-instruction`, so don't ask. Two exceptions:
  - **Stale binding:** if the bound slug is not present in the catalog above (it was retired), clear
    the binding with `find "$HOME/.claude/.INSTRUCTIONS/.active" -name "${CLAUDE_SESSION_ID}" -delete`
    and treat the session as unbound.
  - **Sanity gate:** if what this conversation most recently accomplished is clearly unrelated to the
    bound instruction (the session pivoted to different work after the bound instruction finished),
    do NOT merge unrelated content into it — fall through to the unbound flow and tell the user why.
- **Unbound — suggest and confirm:** compare what this conversation accomplished against the derived
  catalog above (skim candidate `LIB/<slug>/MAIN.md` files when an entry looks close). Then **ask the
  user to choose** (use AskUserQuestion): offer the existing instruction(s) that plausibly match as
  "update `<slug>`" options, plus a "create a new instruction" option — and, if the conversation
  revealed that an existing instruction is obsolete or wrong (not merely incomplete), a
  "retire `<slug>`" option. Do not decide silently. Wait for their answer.
  - If they pick an existing instruction → UPDATE it.
  - If they pick "create new" → infer a short kebab-case slug from what this conversation
    accomplished, plus a one-line `when:` (the "when to use" documentation).
  - If they pick "retire" → skip to "Retire an instruction" below.

Once resolved in the unbound case, persist the binding so further `/save-instruction` calls in this
session reuse the slug — **only if `${CLAUDE_SESSION_ID}` is non-empty**; never write a `.active/`
file with an empty name:
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
  details are pulled in only on demand. Don't inline what a reader won't always need. **See "Keep files
  on-demand-sized" below for the concrete threshold and how to split to minimize reads.**
- If the folder already exists, MERGE into MAIN.md and its detail files — refine and tighten, never
  duplicate; delete detail files that no longer apply. (Destructive merging is safe because every
  save ends in a git commit — see "Version & housekeeping".)

Template for `MAIN.md` — the front matter is **exactly these four keys, in this order**:
```markdown
---
slug: <kebab-case>
title: <short imperative title>
when: <ONE line — when to reuse this instruction; this line IS the catalog entry>
updated: <YYYY-MM-DD>
---

# <title>

## Parameters
- `{{param}}` — <what it is>

## Instructions
1. <imperative step>

## Detailed references (read on demand)
- `<topic>.md` — <what's in it and when to read it>   ← omit this whole section if there are none

## Notes / gotchas
- <hard-won constraints only>
```

**Front-matter discipline — this is what makes the catalog derivable.** Both skills build the catalog
by reading each `MAIN.md`'s first 6 lines (`head -n 6`), so the four keys above must occupy exactly
lines 2–5 between the `---` fences — never reorder them, add keys, or let a value wrap onto a second
line, or it falls outside the window and vanishes from discovery. `when:` must be ONE tight line
stating when to reuse the instruction; implementation details belong in the body, never in `when:`.
Do **not** repeat the when-to-use text as a body line — `when:` is the single source of truth, and a
body copy would drift. If any catalog block at the top of this prompt is missing its `when:` line or
shows overflowing front matter, that instruction is malformed — repair its front matter as part of
this save and mention it in your report.

## Keep files on-demand-sized (split large files, conditionally)
`MAIN.md` is re-read in full every time the instruction is reused, so its length is a recurring cost;
detail files are read only when their one-line trigger fires. Tune the split to **minimize the total
number of file reads across reuse** — most runs should touch only `MAIN.md`.

- **Threshold.** Keep `MAIN.md` lean — aim **≤ ~150 lines**, hard ceiling **~250 lines**. Judge from the
  Read line numbers, or `ls -l "$HOME/.claude/.INSTRUCTIONS/<slug>/MAIN.md"` for bytes. The same ceiling
  applies to each detail file.
- **Under threshold → do NOT split.** One file = one read. Never create detail files speculatively: an
  unneeded file just adds a read when someone goes looking, and an empty "Detailed references" section is
  noise. A short instruction stays a single `MAIN.md`.
- **Over threshold → move the least-always-needed sections out**, keeping the always-needed spine in MAIN
  (front matter, Parameters, the numbered Instructions, the top few gotchas). Migrate long examples,
  command/schema references, per-case edge handling, and background into detail file(s).
- **Split along "read-together" seams to minimize reads.** Each detail file must be a **self-contained
  unit an agent opens once** for one situation — never scatter a single workflow across files it has to
  open together. Prefer **few cohesive files over many tiny ones** (N tiny files ⇒ up to N reads); merge
  related on-demand material under one topic. Split a detail file *further* only when its parts have
  **independent triggers** (so a reader still opens just one).
- **Every MAIN reference names its trigger** ("read `<topic>.md` when you need X") so the reader opens a
  detail file only in that case — and opens exactly the one it needs.
- **On update, rebalance.** After merging new material, re-check `MAIN.md` against the threshold: if it
  crossed, push the overflow down into the right detail file (or a new one) and tighten; pull a detail
  file back up into MAIN if it shrank to a couple of lines; delete detail files that no longer apply.

There is **no index to rebuild** — the catalog is derived from front matter whenever either skill
runs. Never create an `index.md`.

## Retire an instruction (only when explicitly chosen)
Retiring is for instructions whose subject no longer exists or whose approach is invalid — not for
incomplete ones (update those instead). After the user picks "retire `<slug>`":
- First ensure the library is a git repo (Version & housekeeping step A below).
- `git -C "$HOME/.claude/.INSTRUCTIONS" rm -r -q "<slug>"`
- Skip the Consolidate step; go to Version & housekeeping steps B–C with commit message
  `retire <slug>: <one-line reason>`. (The session's binding, if it pointed here, is cleared
  automatically by the stale-binding check on the next save.)

## Version & housekeeping (every save ends here)
The library is a git repository — every save is a commit, so destructive merges are always auditable
and reversible (`git -C "$HOME/.claude/.INSTRUCTIONS" log` / `revert`).
- **A. Ensure the library is a git repo (idempotent).** If
  `git -C "$HOME/.claude/.INSTRUCTIONS" rev-parse --is-inside-work-tree` fails, run
  `git -C "$HOME/.claude/.INSTRUCTIONS" init` and create a `.gitignore` containing the single line
  `.active/` (session bindings are ephemeral state, not library content).
- **B. Prune stale bindings.**
  `find "$HOME/.claude/.INSTRUCTIONS/.active" -type f -mtime +30 -delete 2>/dev/null || true`
- **C. Commit.** `git -C "$HOME/.claude/.INSTRUCTIONS" add -A` then
  `git -C "$HOME/.claude/.INSTRUCTIONS" commit -m "<save|retire> <slug>: <one-line summary>"`.

## Report
Finally, report to the user:
- which slug you created, updated, or retired,
- **what changed** — for a new instruction, a one-line description of what was captured; for an
  update, a short bullet list of what you added, revised, or dropped relative to the previous
  version,
- **the generalization axis** you used — and, if you inferred it (no `$ARGUMENTS`), say so explicitly
  so the user can re-run with a directive if it's wrong, and
- the commit message you used.
