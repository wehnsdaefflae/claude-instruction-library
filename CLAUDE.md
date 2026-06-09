# Project: instruction-consolidation system

A global, command-driven library of reusable instructions lives in `~/.claude/.INSTRUCTIONS/`
(one subfolder per instruction, each a `MAIN.md` brief plus on-demand detail files), shared across
all projects. This repo is the single source of truth for the skills + hook; `./deploy.sh` copies
them into `~/.claude/`.

Workflow:
- **`/use-instruction [slug or description]`** — reuse an existing instruction: load its spec as the
  working brief so it drives the work. Optional, and only for repeating a known kind of work — fresh
  work needs no command. With an argument it loads the match directly; otherwise it shows the catalog
  and asks. Corrections made while working on a loaded instruction get folded back into it.
- **`/save-instruction [what to generalize for]`** — the explicit "Claude got it right" signal. Run
  it when the work succeeded. If bound (via `/use-instruction`) it updates that instruction;
  otherwise it suggests likely matches plus "create new" (and "retire" for an obsolete one) for you to
  confirm, then captures/refines the instruction and commits. The optional argument states the axis
  the instruction should generalize over (what varies between uses); without it, the axis is inferred
  and reported back.

Key design facts:
- **No stored `index.md`.** The catalog is derived from each `MAIN.md`'s front matter (`slug`, `title`,
  `when`, `updated` — exactly those four keys, lines 2–5) every time a skill runs. Nothing to rebuild,
  nothing to drift.
- **Every save is a git commit** in `~/.claude/.INSTRUCTIONS/`, so destructive merges are auditable
  and revertible.
- **A `SessionStart`/`compact` hook** reminds Claude to re-read a bound instruction's `MAIN.md` after
  compaction.
- The library catalog is surfaced only when you run a skill — nothing is injected automatically at
  session start.
