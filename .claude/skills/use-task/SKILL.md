---
name: use-task
description: Reuse an existing task formulation from the global library as the working brief for this conversation. Use when you want to repeat a known task; not needed to start fresh work.
disable-model-invocation: true
allowed-tools: Read Bash(mkdir *) Bash(printf *) Bash(cat *) Bash(ls *)
---

Global task library (absolute path): !`echo "$HOME/.claude/.INSTRUCTIONS"`
This session's id: `${CLAUDE_SESSION_ID}`

Call that library path **LIB**. This command is for **reusing** an existing task — loading its
proven spec so it drives the work from the first turn. (Starting brand-new work needs no command;
just work and run `/save-task` when it's right.)

Do this:

1. Read `LIB/index.md` and show the user the available tasks (slug + "when to use"). If the library
   is empty, say so and stop — there's nothing to reuse yet.

2. Ask the user which task to load. Wait for their answer.

3. Read `LIB/<slug>.md` and adopt it as the working brief for this conversation. Bind the session so
   `/save-task` will refine this exact task — run:
   - `mkdir -p "$HOME/.claude/.INSTRUCTIONS/.active"`
   - `printf '%s\n' '<slug>' > "$HOME/.claude/.INSTRUCTIONS/.active/${CLAUDE_SESSION_ID}"`

4. Tell the user which task is active, then ask for the inputs the task's Parameters need and proceed
   following its Instructions. Any corrections the user makes now will be folded back into this task
   when they run `/save-task`.
