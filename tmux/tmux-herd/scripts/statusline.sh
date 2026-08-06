#!/usr/bin/env bash
# tmux-herd: render per-state agent counts for the tmux status line.
#
# Also acts as the 1Hz maintainer: panes with no hook-reported state get a
# "~state" inferred from their OSC title (Claude/Codex animate a braille
# spinner while working, park at "✳ " when idle, Codex says "Action
# Required" when blocked). Stamping inference into @herd_state is what lets
# the native choose-tree popup see those panes with zero processes spawned.

set -u
LC_ALL=C
TAB=$'\t'

blocked=0 working=0 finished=0 idle=0
stamp=()

# split manually: IFS-based read collapses empty tab fields (empty
# @herd_state would swallow the title), and tmux escapes control-char
# separators in format output, so tabs + parameter expansion it is.
while IFS= read -r line; do
  id=${line%%"$TAB"*}
  rest=${line#*"$TAB"}
  state=${rest%%"$TAB"*}
  title=${rest#*"$TAB"}
  case "$state" in
    '' | '~'*)
      new=""
      case "$title" in
        *"Action Required"*) new="~blocked" ;;
        "✳ "*) new="~idle" ;;
        *)
          # braille spinner: bytes e2 a0..a3 xx followed by a space
          if [ "${title:0:1}" = $'\xe2' ] && [[ "${title:1:1}" == [$'\xa0'-$'\xa3'] ]] \
             && [ "${title:3:1}" = " " ]; then
            new="~working"
          fi
          ;;
      esac
      if [ "$new" != "$state" ]; then
        if [ -n "$new" ]; then
          stamp+=(set-option -pt "$id" @herd_state "$new" ";")
        else
          stamp+=(set-option -put "$id" @herd_state ";")
        fi
      fi
      state="$new"
      ;;
  esac
  case "$state" in
    blocked | '~blocked') blocked=$((blocked + 1)) ;;
    working | '~working') working=$((working + 1)) ;;
    done)                 finished=$((finished + 1)) ;;
    idle | '~idle')       idle=$((idle + 1)) ;;
  esac
done < <(tmux list-panes -a -F "#{pane_id}$TAB#{@herd_state}$TAB#{pane_title}" 2>/dev/null)

# apply all inference updates in a single tmux invocation (trailing ";" dropped)
if [ "${#stamp[@]}" -gt 0 ]; then
  tmux "${stamp[@]:0:${#stamp[@]}-1}" 2>/dev/null || true
fi

out=""
[ "$blocked"  -gt 0 ] && out+="#[fg=red,bold]●$blocked#[default] "
[ "$working"  -gt 0 ] && out+="#[fg=yellow]●$working#[default] "
[ "$finished" -gt 0 ] && out+="#[fg=green]●$finished#[default] "
[ "$idle"     -gt 0 ] && out+="#[fg=colour244]●$idle#[default] "
printf '%s' "${out% }"
