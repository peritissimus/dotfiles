#!/usr/bin/env bash
# tmux-herd: popup listing agent panes by state; pick one to jump to it.
# Uses fzf when available, falls back to a numbered menu.
#
# Perf: one tmux call, one ps call, no per-pane subshells — popup latency
# is dominated by fork count, not data volume.

set -u

# shellcheck source=state-dir.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/state-dir.sh"
dir="$(herd_state_dir)"

TAB=$'\t'

# Detection for panes that don't self-report, cheapest first:
#
# 1. OSC title glyphs (free): Claude Code / Codex animate a braille spinner
#    (U+2800-U+28FF) in the terminal title while working, park it at "✳ "
#    when idle; Codex titles say "Action Required" when blocked.
# 2. Process scan (~100ms on macOS): lazy — only runs if some stateless,
#    title-less pane exists — and cached for 15s, so reopening is instant.
#    Needed because agent TUIs rename their foreground process (Claude Code
#    shows its version string), making #{pane_current_command} unreliable.
LC_ALL=C
AGENT_RE='^(claude|codex|amp|aider|goose|gemini|opencode)$'
map_file="$dir/.agent-map"

inferred=""
title_state() {
  inferred=""
  case "$1" in
    *"Action Required"*) inferred=blocked; return ;;
    "✳ "*) inferred=idle; return ;;
  esac
  # braille spinner: bytes e2 a0..a3 xx followed by a space
  if [ "${1:0:1}" = $'\xe2' ] && [[ "${1:1:1}" == [$'\xa0'-$'\xa3'] ]] \
     && [ "${1:3:1}" = " " ]; then
    inferred=working
  fi
}

agent_map_loaded=""
declare -A agent_by_tty=()
load_agent_map() {
  local tty comm    # do not clobber the caller's loop variables
  [ -n "$agent_map_loaded" ] && return
  agent_map_loaded=1
  mkdir -p "$dir"
  if ! [ -f "$map_file" ] || ! [ -n "$(find "$map_file" -newermt '-15 seconds' 2>/dev/null)" ]; then
    ps -axo tty=,comm= 2>/dev/null > "$map_file" || true
  fi
  while read -r tty comm; do
    comm="${comm##*/}"
    [[ "$comm" =~ $AGENT_RE ]] || continue
    [ -n "${agent_by_tty[$tty]:-}" ] || agent_by_tty[$tty]="$comm"
  done < "$map_file"
}

# "~state" = inferred from the pane title, hollow marker; "state" = hook-reported.
rank=4 label=""
classify() {
  case "$1" in
    blocked)  rank=0; label=$'\033[1;31m● blocked\033[0m' ;;
    ~blocked) rank=0; label=$'\033[1;31m○ blocked\033[0m' ;;
    working)  rank=1; label=$'\033[33m● working\033[0m' ;;
    ~working) rank=1; label=$'\033[33m○ working\033[0m' ;;
    done)     rank=2; label=$'\033[32m● done   \033[0m' ;;
    idle)     rank=3; label=$'\033[90m● idle   \033[0m' ;;
    ~idle)    rank=3; label=$'\033[90m○ idle   \033[0m' ;;
    *)        rank=4; label=$'\033[90m○ agent? \033[0m' ;;
  esac
}

lines=()
# split manually: IFS-based read collapses empty tab fields (empty
# @herd_state would swallow the title)
while IFS= read -r line; do
  id=${line%%"$TAB"*};    rest=${line#*"$TAB"}
  loc=${rest%%"$TAB"*};   rest=${rest#*"$TAB"}
  tty=${rest%%"$TAB"*};   rest=${rest#*"$TAB"}
  cmd=${rest%%"$TAB"*};   rest=${rest#*"$TAB"}
  state=${rest%%"$TAB"*}; title=${rest#*"$TAB"}
  if [ -z "$state" ]; then
    # hook state missing and statusline hasn't stamped an inference yet
    title_state "$title"
    if [ -n "$inferred" ]; then
      state="~$inferred"
    else
      tty="${tty#/dev/}"
      [ -n "$tty" ] || continue
      load_agent_map
      cmd="${agent_by_tty[$tty]:-}"
      [ -n "$cmd" ] || continue
      state="unknown"
    fi
  fi
  classify "$state"
  lines+=("$rank$TAB$id$TAB$label "$'\033[36m'"$loc"$'\033[0m'" $cmd — $title")
done < <(tmux list-panes -a -F "#{pane_id}$TAB#{session_name}:#{window_index}.#{pane_index}$TAB#{pane_tty}$TAB#{pane_current_command}$TAB#{@herd_state}$TAB#{pane_title}")

if [ "${#lines[@]}" -eq 0 ]; then
  echo "tmux-herd: no agent panes found."
  echo "(states appear once agent hooks call hook-update.sh — see README)"
  read -rsn1 -p "press any key to close" || true
  exit 0
fi

sorted="$(printf '%s\n' "${lines[@]}" | sort -t "$TAB" -k1,1n)"

jump() {
  local pane="$1" sess win
  IFS="$TAB" read -r sess win < <(tmux display-message -p -t "$pane" "#{session_name}$TAB#{window_id}")
  tmux switch-client -t "$sess"
  tmux select-window -t "$win"
  tmux select-pane -t "$pane"
}

if command -v fzf >/dev/null 2>&1; then
  choice="$(printf '%s\n' "$sorted" | fzf --ansi --delimiter="$TAB" --with-nth=3.. \
    --no-info --prompt='herd > ' --header='enter: jump to pane, esc: close')" || exit 0
  choice="${choice%%$'\n'*}"
  [ -n "$choice" ] || exit 0
  IFS="$TAB" read -r _ pane _ <<<"$choice"
  jump "$pane"
else
  i=1
  declare -a ids
  while IFS="$TAB" read -r _ id label; do
    ids[$i]="$id"
    printf '%2d) %b\n' "$i" "$label"
    i=$((i + 1))
  done <<<"$sorted"
  printf 'jump to (1-%d, q to close): ' "$((i - 1))"
  read -r pick || exit 0
  [[ "$pick" =~ ^[0-9]+$ ]] && [ -n "${ids[$pick]:-}" ] && jump "${ids[$pick]}"
fi
