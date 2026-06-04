# Inferred task library for Claude Code

Turn the prompt-engineering you do *during* a task into a reusable, validated spec you can pull off
the shelf next time. Two slash commands maintain a global library of **task formulations** in your
user directory — generalized, parameterized instructions for the kinds of work you repeat.

- **`/save-task`** — the "Claude got it right" signal. Run it when a task succeeded; it consolidates
  the conversation into a reusable formulation and indexes it.
- **`/use-task`** — reuse a saved formulation as the working brief so it steers the work from the
  first turn, instead of re-deriving it mid-task.

Nothing runs automatically and nothing is captured unless you ask — so the library only ever holds
tasks you confirmed were done correctly.

## How it works

The library lives at `~/.claude/.INSTRUCTIONS/` and is shared across every project:

```
~/.claude/.INSTRUCTIONS/
  index.md              the catalog (shown when you run /use-task)
  <slug>.md             one reusable formulation per task type
  .active/<session_id>  binding: which task the current session is refining
```

- **New work:** just work. When it's right, `/save-task`. With nothing bound it offers any likely
  existing matches plus "create new" for you to choose, then writes/updates the formulation and
  reports what changed.
- **Repeat work:** `/use-task` → pick a formulation → it becomes the brief and binds the session.
  Corrections you make get folded back in. `/save-task` then updates that task silently (you already
  declared intent) and reports the diff.

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
You:   /save-task
Claude: Created add-fastapi-endpoint — route + schema-wrapping + 404 on missing.

# Session 2 — reuse
You:   /use-task  →  pick add-fastapi-endpoint
Claude: Loaded. Method/path, module, response schema?
You:   POST /orders in app/api/orders.py, schema OrderOut
Claude: …writes it, already including the 404 and schema-wrapping…
You:   Also validate the body with OrderIn and return 201.
Claude: …adds those…
You:   /save-task
Claude: Updated add-fastapi-endpoint: + request-body validation, + success status.
```

## Install (user-wide)

Copy the two skills into your Claude Code skills directory:

```bash
mkdir -p ~/.claude/skills
cp -r .claude/skills/use-task ~/.claude/skills/
cp -r .claude/skills/save-task ~/.claude/skills/
```

`/use-task` and `/save-task` are then available in every conversation. The library directory is
created on first save. To try it in one project only, keep the skills under that project's
`.claude/skills/` instead.

## Notes

- Skills are interactive-only — the commands work in the `claude` CLI, not under `claude -p`.
- The binding files in `.active/` are tiny and persist after sessions; prune occasionally if you
  like.
- To capture a past success, resume that conversation (`claude --resume`) and run `/save-task` — it
  consolidates the conversation in context.
