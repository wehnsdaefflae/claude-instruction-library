# Auto-consolidating instruction library for Claude Code

**Goal.** Claude Code behaves normally for the user, but in the background it watches what the
user asks for, and over time distills it into a reusable, indexed library of *instructions*
under `./.INSTRUCTIONS/`. When a new session starts, the relevant instructions are surfaced so the
user can reuse a polished instruction instead of re-deriving it each time.

All Claude Code features referenced here were verified against the official docs on 2026-06-04
(`code.claude.com/docs/en/hooks`, `/skills`, `/headless`).

---

## 1. The problem, independent of Claude Code

This is **intent / spec mining**: turning a noisy, append-only stream of user utterances
(instructions, mid-conversation corrections, clarifications, "no, do it this way instead") into a clean,
generalized, reusable artifact. Three data layers, each with a different lifecycle:

| Layer | Nature | Lifecycle |
|-------|--------|-----------|
| **Raw capture** | Append-only log of exactly what the user typed, per session | Never edited, lossless audit trail |
| **Consolidated instruction** | One markdown file per *kind of work*, regenerable & idempotent | Rewritten on each consolidation |
| **Index** | Catalog of instructions, used for surfacing/matching | Regenerated from instructions |

The hard parts (and the design choices that address them):

- **Reusable vs. one-off.** Most of what a user says is session-specific ("fix line 42"). Only the
  *generalizable procedure* belongs in an instruction. → Consolidation must **generalize and
  parameterize** (replace concrete file names/values with named slots), and drop one-offs.
- **Corrections override.** Later instructions supersede earlier ones in the same session. →
  Consolidation reads the log **in order** and keeps the final intent, not the first attempt.
- **Idempotent merge.** Re-running on a session that's already captured must update, not duplicate.
  → Instructions are keyed by a stable slug; consolidation merges into the existing file.
- **Clustering into kinds of work.** When does a session belong to an existing instruction vs. a new
  one? → The consolidator is given the current index and decides "extend `X`" or "create new".
- **Cost.** Generalization needs an LLM; running one every turn is wasteful. → **Capture cheaply
  (no LLM), consolidate only at boundaries (LLM).**

---

## 2. Verified Claude Code building blocks

### Hooks (`.claude/settings.json`)
Shell/HTTP/MCP/`prompt`/`agent` handlers fired at lifecycle events. JSON arrives on **stdin**;
every event includes `session_id`, `transcript_path`, `cwd`. Relevant events & powers:

- **SessionStart** — cannot block; **injects context** via plain stdout *or*
  `hookSpecificOutput.additionalContext`. → surface the library at session open.
- **UserPromptSubmit** — receives the literal `prompt` field; can inject context or block. →
  cheaply capture every user utterance.
- **SessionEnd** — cleanup/archival point; cannot block. → run the (expensive) consolidation once
  per session at a natural boundary.
- **Stop** — fires after each assistant turn; can block to force continuation. (Alternative
  consolidation trigger if you want mid-session updates — more costly.)
- **FileChanged** (with `watchPaths` set in a SessionStart response) — react to manual edits of
  `.INSTRUCTIONS/*.md` (e.g. re-index). Optional.

Verified handler fields: `type` (`command|http|mcp_tool|prompt|agent`), `command`, `args`,
`timeout`, **`async`** (run in background, don't block), **`asyncRewake`** (background + wake Claude
on exit 2), **`statusMessage`** (spinner text), `once`, `if`. So background work is first-class.

### Headless mode (`claude -p`)
`claude -p "<prompt>" --allowedTools "Read,Write,Edit" --permission-mode acceptEdits` runs
non-interactively in `cwd`, reads stdin, writes files. This is the **consolidation engine** a
command-hook calls. Notes:
- `--output-format json` exposes `total_cost_usd` for spend tracking.
- User-invoked skills are **not** available under `-p` — pass the full request in the prompt.
- A headless call started inside a hook would itself load project hooks and could re-trigger
  SessionEnd → **recursion**. Guard with an env var (see scaffold) or `--bare` (note: `--bare`
  needs `ANTHROPIC_API_KEY`/`apiKeyHelper`, skipping OAuth).

### Skills (`.claude/skills/<name>/SKILL.md`)
YAML frontmatter + body. Relevant fields: `name`, `description`, `disable-model-invocation: true`
(user-only, for side-effecting actions), `user-invocable: false` (Claude-only background
knowledge), `allowed-tools`, **`context: fork`** + `agent:` (run the skill in an isolated subagent
with no main-chat history), `argument-hint`, `$ARGUMENTS`/`$1`. → home for an on-demand,
user-triggered "consolidate this session now, named" action.

### CLAUDE.md `@`-imports
`@./.INSTRUCTIONS/index.md` in `CLAUDE.md` expands the index into every session's context at
startup — the always-on way to "offer" the library (simpler than, or complementary to, the
SessionStart hook).

### `agent` hook type
`type: "agent"` runs a native subagent from a hook (no subprocess, no separate auth) — the most
elegant consolidation engine, at the cost of being newer/less transparent than `claude -p`. The
scaffold uses `claude -p` for debuggability and lists this as the upgrade path.

---

## 3. Architecture (command-driven, global library)

**Principle: a single global library of instructions in the user directory; the user drives it
with two commands; consolidation happens only on an explicit success signal, so the library only
ever contains instructions Claude got *right*.**

```
~/.claude/.INSTRUCTIONS/          GLOBAL library, shared across every project
  index.md                        the pickable catalog
  <slug>.md                       one reusable instruction per kind of work
  .active/<session_id>            binding: the slug this session is working on

/use-instruction (no arg) ─▶ REUSE path (optional). Read + show the index; user picks a slug; load
   (user-invoked)       <slug>.md as the working brief and write that slug to .active/<session_id>.
                        Not needed for fresh work. This is the ONLY thing that surfaces the index —
                        nothing is injected automatically at session start.

  ... user works; corrections refine the loaded instruction in-conversation ...

/save-instruction (no arg) ─▶ THE SUCCESS SIGNAL. "Claude got it right." Resolve the slug:
   (user-invoked)        bound (.active) → update silently; else SUGGEST likely index matches
                         + a "create new" option and let the user choose. Consolidate this
                         conversation into <slug>.md, rebuild index.md, persist the binding.
```

`/save-instruction` alone is sufficient: starting fresh work needs no command — you work, then save, and
the slug is generated. `/use-instruction` exists only for the reuse direction, where loading a proven spec
*up front* steers the work instead of re-deriving it.

Why this shape:
- **Quality gate.** Nothing enters the library automatically. `/save-instruction` is the human saying
  "this attempt was correct" — so the library is a set of *validated* instructions, not raw attempts.
  This is the answer to "we need a way to know when Claude gets it right."
- **Pick → refine → fold back.** `/use-instruction` makes X the brief; whatever the user corrects while
  working is, on `/save-instruction`, merged back into X (corrected intent wins over the superseded spec).
- **Global & reusable.** Library lives in `~/.claude/.INSTRUCTIONS/`, so any conversation in any
  directory can pick from it.
- **Stateful binding, no arguments.** The active slug is persisted to
  `~/.claude/.INSTRUCTIONS/.active/<session_id>` by `/use-instruction` and read by `/save-instruction`, so both
  commands run with no parameter. If nothing is bound, `/save-instruction` suggests likely index matches and
  a "create new" option for the user to confirm (auto-generating the slug + a one-line doc on new).

### Layout
```
<skills install dir>/.claude/       project .claude/ (this testbed) OR user ~/.claude/
  skills/use-instruction/SKILL.md          reuse-an-existing-instruction command (optional)
  skills/save-instruction/SKILL.md         success-signal / consolidate command

~/.claude/.INSTRUCTIONS/            the global library (user directory)
  index.md
  <slug>.md
  .active/<session_id>             per-session binding: the active instruction slug
```

To make `/use-instruction` and `/save-instruction` available in **every** conversation (not just this project),
move `skills/` into `~/.claude/skills/`. The library itself is already global. This testbed keeps the
skills project-local so testing doesn't alter your global Claude Code setup. There is no hook and no
`settings.json` — the index surfaces only when you run `/use-instruction`.

---

## 4. Tradeoffs & open questions

- **Consolidation quality** lives entirely in `save-instruction/SKILL.md` — the real product surface.
  Iterate that prompt; everything else is plumbing.
- **Binding lifecycle.** `.active/<session_id>` files persist after the session ends and accumulate
  over time. They're tiny; prune them periodically (e.g. a SessionEnd cleanup or a cron). The
  binding is keyed on `${CLAUDE_SESSION_ID}`, so resuming a session keeps its instruction.
- **Cost.** `/save-instruction` runs the model once, in your interactive session (no extra headless call).
  Only fires when you ask.
- **Skills are interactive-only.** `/use-instruction` and `/save-instruction` work in the interactive CLI, not
  under `claude -p`.
- **Discoverability vs. blast radius.** Promoting the skills to `~/.claude/` makes them universal but
  adds two always-available commands to every session — a deliberate choice, hence not done silently.
