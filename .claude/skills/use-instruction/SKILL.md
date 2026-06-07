---
name: use-instruction
description: Reuse an existing instruction from the global library as the working brief for this conversation. Use when you want to repeat a known kind of work; not needed to start fresh work.
disable-model-invocation: true
allowed-tools: Read Bash(mkdir *) Bash(printf *) Bash(cat *) Bash(ls *)
---

Global instruction library (absolute path): !`echo "$HOME/.claude/.INSTRUCTIONS"`
This session's id: `${CLAUDE_SESSION_ID}`

Call that library path **LIB**. This command is for **reusing** an existing instruction — loading its
proven spec so it drives the work from the first turn. (Starting brand-new work needs no command;
just work and run `/save-instruction` when it's right.)

Do this:

1. Read `LIB/index.md` and show the user the available instructions (slug + "when to use"). If the
   library is empty, say so and stop — there's nothing to reuse yet.

2. Ask the user which instruction to load. Wait for their answer.

3. Read `LIB/<slug>.md` and adopt it as the working brief for this conversation. Bind the session so
   `/save-instruction` will refine this exact instruction — run:
   - `mkdir -p "$HOME/.claude/.INSTRUCTIONS/.active"`
   - `printf '%s\n' '<slug>' > "$HOME/.claude/.INSTRUCTIONS/.active/${CLAUDE_SESSION_ID}"`

4. Tell the user which instruction is active, then ask for the inputs its Parameters need and proceed
   following its Instructions.

5. **When you have finished the instruction's steps, close the loop:** tell the user the instruction
   `<slug>` is complete, that they can keep refining or take further actions on top of the result,
   and that running `/save-instruction` when they're done will fold those changes back into this
   instruction (the session is already bound to it). Keep this to one short prompt — don't nag on
   every later turn.
