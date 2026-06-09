#!/usr/bin/env bash
# Deploy the instruction-library system from this repo (the single source of truth) into
# the user's live Claude Code config. Re-run after editing anything in the repo; never
# hand-edit the deployed copies. Idempotent.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="$HOME/.claude"
LIB="$CLAUDE/.INSTRUCTIONS"

echo "Deploying from: $REPO"

# 1. Skills — copy (not symlink) into ~/.claude/skills/<name>/SKILL.md
for skill in save-instruction use-instruction; do
  src="$REPO/.claude/skills/$skill/SKILL.md"
  dst_dir="$CLAUDE/skills/$skill"
  mkdir -p "$dst_dir"
  cp -f "$src" "$dst_dir/SKILL.md"
  echo "  skill  -> $dst_dir/SKILL.md"
done

# 2. Hook — copy into ~/.claude/hooks/ so the live config has no runtime dependency on the repo
mkdir -p "$CLAUDE/hooks"
HOOK_DST="$CLAUDE/hooks/bound-instruction-reminder.py"
cp -f "$REPO/hooks/bound-instruction-reminder.py" "$HOOK_DST"
chmod +x "$HOOK_DST"
echo "  hook   -> $HOOK_DST"

# 3. Register the SessionStart(compact) hook in settings.json — idempotent, preserves all
#    existing keys, bakes in the concrete absolute path (no shell expansion assumptions).
SETTINGS="$CLAUDE/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
python3 - "$SETTINGS" "$HOOK_DST" <<'PY'
import json, sys
settings_path, hook_path = sys.argv[1], sys.argv[2]
with open(settings_path) as f:
    s = json.load(f)
cmd = f"python3 {hook_path}"
hooks = s.setdefault("hooks", {})
session_start = hooks.setdefault("SessionStart", [])
already = any(
    h.get("command") == cmd
    for entry in session_start
    for h in entry.get("hooks", [])
)
if not already:
    session_start.append({
        "matcher": "compact",
        "hooks": [{"type": "command", "command": cmd}],
    })
    with open(settings_path, "w") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    print("  hook registered in settings.json (SessionStart/compact)")
else:
    print("  hook already registered in settings.json (no change)")
PY

# 4. Ensure the instruction library is a git repo (so every save is auditable/revertible)
if [ -d "$LIB" ]; then
  if ! git -C "$LIB" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$LIB" init -q
    printf '%s\n' '.active/' > "$LIB/.gitignore"
    echo "  library git repo initialized at $LIB"
  else
    echo "  library already a git repo"
  fi
else
  echo "  library not present yet ($LIB) — it is created on first /save-instruction"
fi

echo "Done. /save-instruction and /use-instruction are deployed."
