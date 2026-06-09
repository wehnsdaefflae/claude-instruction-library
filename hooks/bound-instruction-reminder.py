#!/usr/bin/env python3
"""SessionStart(compact) hook for the instruction library.

If this session is bound to an instruction (~/.claude/.INSTRUCTIONS/.active/<session_id>),
remind Claude after a compaction to re-read that instruction's MAIN.md, since the brief's
exact steps and gotchas do not survive compaction.

Registered in ~/.claude/settings.json under hooks.SessionStart with matcher "compact".
Reads the hook event JSON on stdin, emits the documented additionalContext JSON on stdout,
and ALWAYS exits 0 — a SessionStart hook must never disrupt a session.
"""
import json
import os
import sys


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    session_id = str(data.get("session_id") or "").strip()
    if not session_id or "/" in session_id or session_id in (".", ".."):
        return  # guard against path traversal / empty id
    lib = os.path.expanduser("~/.claude/.INSTRUCTIONS")
    binding = os.path.join(lib, ".active", session_id)
    try:
        with open(binding) as f:
            slug = f.read().strip()
    except OSError:
        return
    if not slug:
        return
    main_md = os.path.join(lib, slug, "MAIN.md")
    if not os.path.isfile(main_md):
        return
    context = (
        f"This session is bound to the instruction '{slug}'. The conversation was just "
        f"compacted, so the brief's exact steps may no longer be in context — re-read "
        f"{main_md} before continuing its steps."
    )
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context}},
        sys.stdout,
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never fail a SessionStart hook
    sys.exit(0)
