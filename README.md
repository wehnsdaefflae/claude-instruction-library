# Inferred instruction library for Claude Code

Turn the prompt-engineering you do *during* a piece of work into a reusable, validated instruction
you can pull off the shelf next time. Two slash commands maintain a global library of **instructions**
in your user directory — generalized, parameterized briefs for the kinds of work you repeat.

- **`/save-instruction [what to generalize for]`** — the "Claude got it right" signal. Run it when
  the work succeeded; it consolidates the conversation into a reusable instruction. The optional
  argument tells it what should vary between uses (the reuse axis) so it parameterizes the right
  things; without it, the axis is used if clear, or — if ambiguous — you're asked with a clickable
  choice (plus free-text) instead of it guessing.
- **`/use-instruction [slug or description]`** — reuse a saved instruction as the working brief so it
  steers the work from the first turn. With an argument it loads the matching instruction directly;
  without one it shows the catalog and asks.

Nothing runs automatically and nothing is captured unless you ask — so the library only ever holds
instructions you confirmed produced correct work.

This repository is the **single source of truth**. Editing happens here; `./deploy.sh` copies the
skills and the hook into your live `~/.claude/`. Never hand-edit the deployed copies — re-run
`deploy.sh` after changing anything here.

## How it works

The library lives at `~/.claude/.INSTRUCTIONS/` and is shared across every project:

```
~/.claude/.INSTRUCTIONS/
  .git/                 every save is a commit — merges are auditable & revertible
  <slug>/               one subfolder per kind of work
    MAIN.md             the always-loaded brief (front matter + body)
    <topic>.md          deep-detail files, read on demand
  .active/<session_id>  binding: which instruction the current session is refining (gitignored)
```

There is **no `index.md`.** The catalog is *derived* from each instruction's front matter every time
a skill runs (the skill front matter contains a `` !`head -n 6 .../MAIN.md` `` line that injects it),
so it can never drift from the instructions themselves. Each `MAIN.md` begins with exactly four
front-matter keys:

```markdown
---
slug: <kebab-case>
title: <short imperative title>
when: <one line — when to reuse this; THIS is the catalog entry>
updated: <YYYY-MM-DD>
---
```

Instructions use the same progressive-disclosure pattern as skills: `MAIN.md` is loaded every time,
while bulky detail (long examples, schemas, edge cases) lives in sibling files that are read only when
a step calls for them — so an instruction can be very thorough without flooding the context.

- **New work:** just work. When it's right, `/save-instruction`. With nothing bound it offers any
  likely existing matches plus "create new" (and "retire" if it spots an obsolete one) for you to
  choose, then writes/updates the instruction, commits, and reports what changed.
- **Repeat work:** `/use-instruction` → pick (or name) an instruction → it becomes the brief and binds
  the session. Corrections you make get folded back in; `/save-instruction` then updates that
  instruction silently (you already declared intent) and commits the diff.

Consolidation generalizes the conversation: concrete values become `{{parameters}}`, mid-session
corrections override the superseded version, and re-saving merges into the existing file rather than
duplicating it. Because every save is a git commit, a bad merge is always recoverable.

### Surviving compaction

A `SessionStart` hook (matcher `compact`) checks whether this session is bound to an instruction and,
if so, reminds Claude to re-read that instruction's `MAIN.md` after a compaction — since the brief's
exact steps don't survive being compacted. Sessions with no binding get nothing.

See [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) for the full design, the Claude Code mechanisms it relies
on, and the tradeoffs.

## Install (user-wide)

```bash
./deploy.sh
```

This copies the two skills into `~/.claude/skills/`, copies the hook into `~/.claude/hooks/`,
registers the `SessionStart`/`compact` hook in `~/.claude/settings.json` (idempotently, preserving
your existing settings), and ensures the library directory is a git repo. `/use-instruction` and
`/save-instruction` are then available in every conversation. The library directory is created on
first save if it doesn't exist yet.

## Releasing

Cutting a release is one command once the changelog is updated:

1. Move your `## [Unreleased]` bullets into a new `## [X.Y.Z] - YYYY-MM-DD` section, add its
   `[X.Y.Z]: …/compare/…` link reference, and commit that.
2. `./release.sh X.Y.Z` — extracts that section's notes, tags `vX.Y.Z` at `HEAD`, pushes, and creates
   the matching GitHub release (marked Latest only if it's the highest version).

Run `./release.sh X.Y.Z --dry-run` first to preview the notes and planned actions without changing
anything.

## Notes

- Skills are interactive-only — the commands work in the `claude` CLI, not under `claude -p`.
- The binding files in `.active/` are tiny, gitignored, and pruned automatically (entries older than
  30 days) on each save.
- To capture a past success, resume that conversation (`claude --resume`) and run `/save-instruction`
  — it consolidates the conversation in context.
