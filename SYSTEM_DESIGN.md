# Command-driven instruction library for Claude Code

**Goal.** Claude Code behaves normally, but on an explicit success signal it distills the
conversation into a reusable, generalized *instruction* under `~/.claude/.INSTRUCTIONS/`. Next time
you do that kind of work, you load the polished instruction instead of re-deriving it. The library
only ever contains instructions you confirmed were correct.

Claude Code features referenced here were verified against the official docs
(`code.claude.com/docs/en/skills`, `/hooks`, `/slash-commands`) on 2026-06-10.

---

## 1. The problem, independent of Claude Code

This is **intent / spec mining**: turning a noisy, append-only stream of user utterances
(instructions, mid-conversation corrections, "no, do it this way instead") into a clean, generalized,
reusable artifact. Two data layers:

| Layer | Nature | Lifecycle |
|-------|--------|-----------|
| **Consolidated instruction** | One subfolder per *kind of work* — a `MAIN.md` brief + on-demand detail files, regenerable & idempotent | Rewritten on each save; every save is a git commit |
| **Catalog** | Slug + one-line "when to use" per instruction, for surfacing/matching | **Derived** from front matter on read — never stored |

The hard parts and the choices that address them:

- **Reusable vs. one-off.** Most of what a user says is session-specific ("fix line 42"). Only the
  *generalizable procedure* belongs in an instruction. → Consolidation **generalizes and
  parameterizes** (concrete values become `{{named slots}}`) and drops one-offs.
- **Corrections override.** Later instructions supersede earlier ones in the same session. →
  Consolidation keeps the final intent, not the first attempt.
- **Idempotent merge.** Re-running on already-captured work must update, not duplicate. → Instructions
  are keyed by a stable slug; consolidation merges into the existing file. Every merge is a commit, so
  a bad one is revertible.
- **Generalization axis.** What should vary between uses vs. stay fixed? → Resolved at *save* time
  (from the optional argument, else inferred, else asked), so reuse needs no further intervention.
- **No catalog drift.** A hand-maintained index inevitably diverges from the instructions. → The
  catalog is **derived from front matter** every time a skill runs; there is nothing to rebuild.

---

## 2. Verified Claude Code building blocks

### Skills (`.claude/skills/<name>/SKILL.md`)
YAML frontmatter + body. Fields used here: `name`, `description`, `disable-model-invocation: true`
(user-only — saving and loading are side-effecting, so the model must not auto-fire them),
`allowed-tools`, `argument-hint`, and `$ARGUMENTS` substitution.

**Dynamic context injection (`` !`cmd` ``).** A line like `` !`head -n 6 .../MAIN.md` `` in a SKILL.md
body is executed *before* the skill content reaches the model, and its stdout replaces the line. This
is how the catalog is injected live with no stored file. The commands used this way must be listed in
`allowed-tools` (e.g. `Bash(head *)`, `Bash(cat *)`, `Bash(echo *)`), and `${CLAUDE_SESSION_ID}` is a
documented skill substitution token available in the body and these commands.

### Hooks (`~/.claude/settings.json`)
`SessionStart` supports matchers `startup`, `resume`, `clear`, `compact`. It receives event JSON on
stdin (including `session_id`, `source`) and can inject context via
`hookSpecificOutput.additionalContext`. Hook-injected context does **not** survive compaction — which
is exactly why the `compact` matcher exists: it lets us re-inject after each compaction. We use it for
a single, tightly-scoped reminder (see §3).

### Git
The library directory is a git repository. `/save-instruction` commits after every
create/update/retire, making destructive merges auditable (`git log`) and reversible (`git revert`),
and giving cross-machine sync for free.

---

## 3. Architecture

**Principle: a single global library; the user drives it with two commands; consolidation happens
only on an explicit success signal; the catalog is derived, never stored.**

```
~/.claude/.INSTRUCTIONS/          GLOBAL library, shared across every project
  .git/                           every save is a commit
  .gitignore                      ignores .active/
  <slug>/MAIN.md                  one reusable instruction per kind of work (+ on-demand detail files)
  <slug>/<topic>.md               deep-detail files, read on demand
  .active/<session_id>            binding: the slug this session is refining (ephemeral, gitignored)
```

There is **no `index.md`**. Both skills carry a `` !`head -n 6 .../*/MAIN.md` `` line that injects the
catalog (slug / title / `when` / updated, per instruction) at load time, derived fresh from the front
matter.

```
/use-instruction [slug|desc] ─▶ REUSE (optional). Resolve the instruction from the argument (direct
   (user-invoked)       load on an unambiguous match) or by showing the derived catalog and asking;
                        load <slug>/MAIN.md as the working brief (detail files on demand); bind the
                        session by writing the slug to .active/<session_id>.

  ... user works; corrections refine the loaded instruction in-conversation ...

/save-instruction [axis] ─▶ THE SUCCESS SIGNAL. Resolve the slug: bound (.active) → update (unless the
   (user-invoked)        binding is stale or the work clearly pivoted — then fall through); else
                         SUGGEST catalog matches + "create new" (+ "retire" for an obsolete one) and
                         let the user choose. Consolidate this conversation into <slug>/MAIN.md
                         (pushing bulky detail into sibling files) along the generalization axis (from
                         the optional arg, else inferred), then COMMIT.
```

`/save-instruction` alone suffices for fresh work: you work, then save, and the slug is generated.
`/use-instruction` exists only for the reuse direction.

Why this shape:
- **Quality gate.** Nothing enters the library automatically. `/save-instruction` is the human saying
  "this attempt was correct" — the library is a set of *validated* instructions.
- **Pick → refine → fold back.** `/use-instruction` makes X the brief; whatever the user corrects is,
  on `/save-instruction`, merged back into X (corrected intent wins).
- **Derived catalog.** No rebuild step exists, so no rebuild step can be wrong, and manual edits to a
  `MAIN.md` show up in the catalog instantly. The front-matter contract (four keys, lines 2–5) is what
  makes `head -n 6` a complete extractor.
- **Stateful binding.** The active slug is persisted to `.active/<session_id>`, so it is never typed.
  A stale binding (slug retired) or a clear topic pivot makes `/save-instruction` fall through to the
  suggest-and-confirm flow rather than silently merging into the wrong instruction.

### Surviving compaction
A `SessionStart` hook registered for the `compact` matcher
(`hooks/bound-instruction-reminder.py`) reads `.active/<session_id>`; if this session is bound to an
instruction, it injects a one-line reminder to re-read that instruction's `MAIN.md` (whose exact steps
the compaction may have summarized away). Unbound sessions get nothing. The hook always exits 0 and
guards against empty/path-traversal session ids — a SessionStart hook must never disrupt a session.

### Deployment
This repo is the single source of truth. `./deploy.sh` **copies** (not symlinks) the skills into
`~/.claude/skills/` and the hook into `~/.claude/hooks/`, registers the hook in `settings.json`
idempotently (preserving existing keys, baking in the concrete absolute path), and ensures the library
is a git repo. Re-run after any edit; never hand-edit the deployed copies.

---

## 4. Tradeoffs & open questions

- **Consolidation quality** lives in `save-instruction/SKILL.md` — the real product surface. Iterate
  that prompt; everything else is plumbing.
- **Binding lifecycle.** `.active/<session_id>` files are gitignored and pruned automatically (>30
  days) on each save, so they no longer accumulate. The binding is keyed on `${CLAUDE_SESSION_ID}`, so
  resuming a session keeps its instruction.
- **`${CLAUDE_SESSION_ID}` inside `` !`...` ``.** Documented as a skill substitution token; if it ever
  fails to expand, the bound-slug line reads an empty path and the skill safely falls back to the
  unbound (ask) flow — a benign degradation, never wrong data.
- **Skills are interactive-only.** Both commands work in the interactive CLI, not under `claude -p`.
- **Cost.** `/save-instruction` runs the model once, in your interactive session — no extra headless
  call, and only when you ask.
- **Discoverability vs. blast radius.** The two commands are always available once deployed — a
  deliberate choice, hence `deploy.sh` is explicit, not silent. The catalog is surfaced only on skill
  invocation; nothing is injected at session start.
- **Catalog scale.** `head -n 6` over every instruction is trivial at tens of instructions. At
  hundreds, a `--grep`/category filter or tiered injection would be the next step.
