# Project: instruction-consolidation testbed

A global, command-driven library of reusable task formulations lives in `~/.claude/.INSTRUCTIONS/`
(index + one file per task), shared across all projects.

Workflow:
- **`/use-task`** — reuse an existing task: load its spec as the working brief so it drives the
  work. Optional, and only for repeating a known task — fresh work needs no command. Corrections
  made while working on a loaded task get folded back into it.
- **`/save-task`** — the explicit "Claude got it right" signal (no argument). Run it when the task
  succeeded. If bound (via `/use-task`) it updates that task; otherwise it suggests likely matches
  plus "create new" for you to confirm, then captures/refines the formulation and rebuilds the index.

The library index is shown only when you run `/use-task` — nothing is injected automatically.
