# Inferred instruction library for Claude Code

Turn the prompt-engineering you do *during* a piece of work into a reusable, validated instruction
you can pull off the shelf next time. Two slash commands maintain a global library of **instructions**
in your user directory — generalized, parameterized briefs for the kinds of work you repeat.

- **`/save-instruction [what to generalize for]`** — the "Claude got it right" signal. Run it when
  the work succeeded; it consolidates the conversation into a reusable instruction and indexes it. The
  optional argument tells it what should vary between uses (the reuse axis) so it parameterizes the
  right things; without it, that axis is inferred and reported back.
- **`/use-instruction`** — reuse a saved instruction as the working brief so it steers the work from
  the first turn, instead of re-deriving it each time.

Nothing runs automatically and nothing is captured unless you ask — so the library only ever holds
instructions you confirmed produced correct work.

## How it works

The library lives at `~/.claude/.INSTRUCTIONS/` and is shared across every project:

```
~/.claude/.INSTRUCTIONS/
  index.md              the catalog (shown when you run /use-instruction)
  <slug>.md             one reusable instruction per kind of work
  .active/<session_id>  binding: which instruction the current session is refining
```

- **New work:** just work. When it's right, `/save-instruction`. With nothing bound it offers any
  likely existing matches plus "create new" for you to choose, then writes/updates the instruction
  and reports what changed.
- **Repeat work:** `/use-instruction` → pick an instruction → it becomes the brief and binds the
  session. Corrections you make get folded back in. `/save-instruction` then updates that instruction
  silently (you already declared intent) and reports the diff.

Consolidation generalizes the conversation: concrete values become `{{parameters}}`, mid-session
corrections override the superseded version, and re-saving merges into the existing file rather than
duplicating it.

See [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) for the full design, the Claude Code mechanisms it relies
on, and the tradeoffs.

## Example

```
# Session 1 — first time
You:   Add a GET /users/{id} endpoint to app/api/users.py returning JSON.
Claude: …writes it…
You:   It must 404 when missing and serialize through the UserOut schema.
Claude: …adds those…
You:   /save-instruction
Claude: Created add-fastapi-endpoint — route + schema-wrapping + 404 on missing.

# Session 2 — reuse
You:   /use-instruction  →  pick add-fastapi-endpoint
Claude: Loaded. Method/path, module, response schema?
You:   POST /orders in app/api/orders.py, schema OrderOut
Claude: …writes it, already including the 404 and schema-wrapping…
You:   Also validate the body with OrderIn and return 201.
Claude: …adds those…
You:   /save-instruction
Claude: Updated add-fastapi-endpoint: + request-body validation, + success status.
```

## Install (user-wide)

Copy the two skills into your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills
cp -r .claude/skills/use-instruction ~/.claude/skills/
cp -r .claude/skills/save-instruction ~/.claude/skills/
```

`/use-instruction` and `/save-instruction` are then available in every conversation. The library
directory is created on first save. To try it in one project only, keep the skills under that
project's `.claude/skills/` instead.

## Notes

- Skills are interactive-only — the commands work in the `claude` CLI, not under `claude -p`.
- The binding files in `.active/` are tiny and persist after sessions; prune occasionally if you
  like.
- To capture a past success, resume that conversation (`claude --resume`) and run `/save-instruction`
  — it consolidates the conversation in context.
