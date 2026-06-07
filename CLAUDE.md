# Project: instruction-consolidation testbed

A global, command-driven library of reusable instructions lives in `~/.claude/.INSTRUCTIONS/`
(index + one subfolder per instruction, each a `MAIN.md` brief plus on-demand detail files), shared
across all projects.

Workflow:
- **`/use-instruction`** — reuse an existing instruction: load its spec as the working brief so it
  drives the work. Optional, and only for repeating a known kind of work — fresh work needs no
  command. Corrections made while working on a loaded instruction get folded back into it.
- **`/save-instruction [what to generalize for]`** — the explicit "Claude got it right" signal. Run
  it when the work succeeded. If bound (via `/use-instruction`) it updates that instruction;
  otherwise it suggests likely matches plus "create new" for you to confirm, then captures/refines the
  instruction and rebuilds the index. The optional argument states the axis the instruction should
  generalize over (what varies between uses); without it, the axis is inferred and reported back.

The library index is shown only when you run `/use-instruction` — nothing is injected automatically.
