#!/usr/bin/env bash
# Shared: resolve the herd state directory. Sourced by the other scripts.

herd_state_dir() {
  local dir="${TMUX_HERD_STATE_DIR:-}"
  if [ -z "$dir" ]; then
    dir="${TMPDIR:-/tmp}"
    dir="${dir%/}/tmux-herd-$(id -u)"
  fi
  printf '%s' "$dir"
}
