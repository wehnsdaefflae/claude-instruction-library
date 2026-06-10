# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). While pre-1.0, breaking
changes are released as MINOR bumps. Versions are reconstructed from git history; there are no tags
yet.

## [Unreleased]

## [0.3.0] - 2026-06-10

The catalog becomes derived instead of stored, and the library gains versioning and
compaction-resilience. **Breaking:** the stored `index.md` is gone and every instruction's front
matter now requires a `when:` key.

### Added
- **`when:` front-matter key** — a one-line "when to reuse this" entry, now the single source of
  truth for the catalog.
- **Derived catalog.** Both skills inject the catalog live via a `` !`head -n 6 .../MAIN.md` `` line
  in their front matter, read fresh from each instruction's front matter on every invocation. There
  is nothing to rebuild and nothing to drift.
- **Git versioning of the library.** `/save-instruction` runs `git init` on first use and commits
  after every save and retire, so destructive merges are auditable (`git log`) and reversible
  (`git revert`).
- **`SessionStart`/`compact` hook** (`hooks/bound-instruction-reminder.py`) — after a compaction,
  reminds Claude to re-read a bound session's `MAIN.md`, whose exact steps the compaction may have
  summarized away. Silent for unbound sessions; always exits 0; guards against empty / path-traversal
  session ids.
- **Optional argument to `/use-instruction`** (`[slug or description]`) — loads an unambiguous match
  directly instead of always showing the catalog and asking.
- **Retire flow** in `/save-instruction` — offers to remove an instruction whose subject is obsolete
  (`git rm` + commit), distinct from updating an incomplete one.
- **Stale-binding and topic-pivot sanity gates** — a bound session falls back to suggest-and-confirm
  if the bound slug was retired or the conversation clearly pivoted, instead of silently merging
  unrelated work into the wrong instruction.
- **`.active/` pruning** — binding files older than 30 days are deleted on each save, so they no
  longer accumulate.
- **Empty-`CLAUDE_SESSION_ID` guard** around all binding writes.
- **`deploy.sh`** — copies the skills into `~/.claude/skills/` and the hook into `~/.claude/hooks/`,
  registers the hook in `settings.json` idempotently (preserving existing keys), and ensures the
  library is a git repo. The repo is the single source of truth; deployment is a copy.

### Changed
- Catalog is derived from front matter rather than a hand-maintained `index.md`.
- `.active/` session bindings are now gitignored (ephemeral local state, not library content).
- Skill `allowed-tools` corrected so every `` !`cmd` `` used for dynamic injection (`echo`/`cat`/
  `head`) is allowlisted.
- `README.md`, `CLAUDE.md`, and `SYSTEM_DESIGN.md` rewritten to describe the derived-catalog design,
  versioning, the hook, and `deploy.sh`.

### Removed
- **`index.md`** — the stored, hand-maintained catalog. Eliminates the drift class entirely.
- The body `**When to use:**` line in instructions — superseded by the `when:` front-matter key
  (kept it in two places only invites drift).

### Fixed
- **Catalog drift.** The old index rebuild was specified to read "from front matter," but the front
  matter lacked the when-to-use field, so the index could (and did) diverge from the instructions it
  described.

### Migration
- Existing instructions need a `when:` line so their front matter is `slug` / `title` / `when` /
  `updated` on lines 2–5. The five instructions in the live library were migrated, the library was
  made a git repo, and `index.md` was removed.
- Run `./deploy.sh`, then restart Claude Code so the new `settings.json` hook takes effect (skill
  changes are picked up without a restart).

## [0.2.1] - 2026-06-09

### Changed
- `/save-instruction`: added file-sizing guidance so `MAIN.md` stays lean and bulky material is split
  into on-demand detail files along read-together seams, minimizing total reads across reuse.

## [0.2.0] - 2026-06-07

### Added
- Optional generalization-axis argument to `/save-instruction` (states what should vary between
  uses), with an AskUserQuestion fallback when the axis is ambiguous instead of guessing.
- `/use-instruction` closes the loop when an instruction's steps complete, prompting to refine and
  re-save.

### Changed
- Instructions restructured as subfolders: a `MAIN.md` always-loaded brief plus on-demand detail
  files (progressive disclosure), replacing single flat files.

## [0.1.0] - 2026-06-04

### Added
- Initial instruction library: the `/save-instruction` and `/use-instruction` commands, a global
  library under `~/.claude/.INSTRUCTIONS/`, and per-session bindings.
- Renamed the unit from "task" to "instruction" across commands and docs.

[Unreleased]: https://github.com/wehnsdaefflae/claude-instruction-library/compare/ec00962...HEAD
[0.3.0]: https://github.com/wehnsdaefflae/claude-instruction-library/compare/2e3ec79...ec00962
[0.2.1]: https://github.com/wehnsdaefflae/claude-instruction-library/compare/7d5e61d...2e3ec79
[0.2.0]: https://github.com/wehnsdaefflae/claude-instruction-library/compare/6a78d20...7d5e61d
[0.1.0]: https://github.com/wehnsdaefflae/claude-instruction-library/commits/4778322
