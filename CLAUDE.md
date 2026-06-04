# Project: instruction-consolidation testbed

A global, command-driven library of reusable instructions lives in `~/.claude/.INSTRUCTIONS/`
(index + one file per instruction), shared across all projects.

Workflow:
- **`/use-instruction`** — reuse an existing instruction: load its spec as the working brief so it
  drives the work. Optional, and only for repeating a known kind of work — fresh work needs no
  command. Corrections made while working on a loaded instruction get folded back into it.
- **`/save-instruction`** — the explicit "Claude got it right" signal (no argument). Run it when the
  work succeeded. If bound (via `/use-instruction`) it updates that instruction; otherwise it
  suggests likely matches plus "create new" for you to confirm, then captures/refines the instruction
  and rebuilds the index.

The library index is shown only when you run `/use-instruction` — nothing is injected automatically.
