---
name: use-instruction
description: Reuse an existing instruction from the global library as the working brief for this conversation. Use when you want to repeat a known kind of work; not needed to start fresh work.
disable-model-invocation: true
argument-hint: "[optional: slug or description of the instruction to load]"
allowed-tools: Read AskUserQuestion Bash(echo *) Bash(head *) Bash(mkdir *) Bash(printf *) Bash(ls *)
---

Global instruction library (absolute path): !`echo "$HOME/.claude/.INSTRUCTIONS"`
Catalog — derived live from each instruction's front matter; there is **no stored index**:
!`head -n 6 "$HOME"/.claude/.INSTRUCTIONS/*/MAIN.md 2>/dev/null || true`

Requested instruction (optional): `$ARGUMENTS`

Call that library path **LIB**. This command is for **reusing** an existing instruction — loading its
proven spec so it drives the work from the first turn. (Starting brand-new work needs no command;
just work and run `/save-instruction` when it's right.)

Do this:

1. If the catalog above is empty, say so and stop — there's nothing to reuse yet.

2. Resolve which instruction to load:
   - **Argument given:** match `$ARGUMENTS` against the catalog — exact slug first, then an
     unambiguous match on slug / title / `when:`. Exactly one match → load it directly, no question
     needed. Several plausible matches → AskUserQuestion with those candidates. No match → say so,
     show the catalog (slug + `when:` per instruction), and ask.
   - **No argument:** show the user the available instructions (slug + `when:`) and ask which to
     load — via AskUserQuestion when there are 4 or fewer (it adds a free-text "Other"
     automatically), otherwise list them and ask in prose. Wait for the answer.

3. Read **only** `LIB/<slug>/MAIN.md` and adopt it as the working brief for this conversation. Do NOT
   pre-read the other files in the subfolder — `MAIN.md` lists detail files under "Detailed references"
   and tells you when each is relevant; read `LIB/<slug>/<topic>.md` on demand, only when a step you're
   actually performing calls for it. This keeps context lean for extensive instructions.
   Bind the session so `/save-instruction` will refine this exact instruction — **only if
   `${CLAUDE_SESSION_ID}` is non-empty** (skip binding silently otherwise):
   - `mkdir -p "$HOME/.claude/.INSTRUCTIONS/.active"`
   - `printf '%s\n' '<slug>' > "$HOME/.claude/.INSTRUCTIONS/.active/${CLAUDE_SESSION_ID}"`

4. Tell the user which instruction is active, then ask for the inputs its Parameters need and proceed
   following MAIN.md's Instructions, pulling in detail files only as the steps require.
   If at any later point the brief's exact steps are no longer in context (e.g. after the
   conversation was compacted), re-read `LIB/<slug>/MAIN.md` before continuing them.

5. **When you have finished the instruction's steps, close the loop:** tell the user the instruction
   `<slug>` is complete, that they can keep refining or take further actions on top of the result,
   and that running `/save-instruction` when they're done will fold those changes back into this
   instruction (the session is already bound to it). Keep this to one short prompt — don't nag on
   every later turn.
