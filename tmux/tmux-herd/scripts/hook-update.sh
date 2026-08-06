#!/usr/bin/env bash
# tmux-herd: self-report agent state for the current pane.
#
# Usage: hook-update.sh <working|blocked|done|idle|clear>
#
# Designed to be called from agent lifecycle hooks (e.g. Claude Code hooks)
# running inside a tmux pane. Reads the pane id from $TMUX_PANE. Safe no-op
# outside tmux. Ignores stdin (Claude Code hooks pipe JSON in).
#
# State lives in a tmux pane user option (@herd_state), so it is destroyed
# with the pane and readable natively by choose-tree/status formats.
# Inferred (title-based) states are stored as "~state" by statusline.sh;
# hook reports always overwrite them.

set -u

state="${1:-}"
case "$state" in
  working|blocked|done|idle|clear) ;;
  *) echo "usage: $0 working|blocked|done|idle|clear" >&2; exit 2 ;;
esac

[ -n "${TMUX_PANE:-}" ] || exit 0

if [ "$state" = "clear" ]; then
  tmux set-option -put "$TMUX_PANE" @herd_state \; refresh-client -S 2>/dev/null || true
else
  tmux set-option -pt "$TMUX_PANE" @herd_state "$state" \; refresh-client -S 2>/dev/null || true
fi
exit 0
