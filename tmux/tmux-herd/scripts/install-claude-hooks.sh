#!/usr/bin/env bash
# tmux-herd: wire Claude Code lifecycle hooks to hook-update.sh.
#
# Merges tmux-herd hook entries into ~/.claude/settings.json (or the file
# given as $1). Idempotent: removes any previous tmux-herd entries first.
# A timestamped backup of the settings file is written alongside it.

set -euo pipefail

SETTINGS="${1:-$HOME/.claude/settings.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/hook-update.sh"

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
  echo "backed up $SETTINGS"
fi

python3 - "$SETTINGS" "$HOOK" <<'PY'
import json, os, sys

settings_path, hook = sys.argv[1], sys.argv[2]

# Which herd state each Claude Code lifecycle event maps to.
EVENTS = {
    "SessionStart":     "idle",
    "UserPromptSubmit": "working",
    "PreToolUse":       "working",
    "Stop":             "done",
    "Notification":     "blocked",
    "SessionEnd":       "clear",
}

settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)

hooks = settings.setdefault("hooks", {})

def is_herd(entry):
    return any("tmux-herd" in h.get("command", "") for h in entry.get("hooks", []))

for event, state in EVENTS.items():
    entries = [e for e in hooks.get(event, []) if not is_herd(e)]
    entries.append({"hooks": [{"type": "command", "command": f"{hook} {state}"}]})
    hooks[event] = entries

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print(f"tmux-herd hooks installed into {settings_path}")
PY
