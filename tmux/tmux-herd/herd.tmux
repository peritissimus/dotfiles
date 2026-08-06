#!/usr/bin/env bash
# tmux-herd — agent-aware status for tmux. TPM entry point.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_opt() { tmux show-option -gqv "$1"; }

# One colored glyph per agent state; empty for stateless panes.
# "~state" = inferred from OSC title (hollow ○), bare = hook-reported (●).
# NB: no commas inside #[...] styles — they would split the surrounding
# #{?,,} conditional arguments.
GLYPH='#{?#{==:#{@herd_state},blocked},#[fg=red]●#[default] ,#{?#{==:#{@herd_state},~blocked},#[fg=red]○#[default] ,#{?#{m:*working,#{@herd_state}},#{?#{==:#{@herd_state},working},#[fg=yellow]●#[default] ,#[fg=yellow]○#[default] },#{?#{==:#{@herd_state},done},#[fg=green]●#[default] ,#{?#{m:*idle,#{@herd_state}},#[fg=colour244]●#[default] ,}}}}}'

# Tree lines: sessions plain; windows show every agent pane's glyph plus the
# active pane's title; expanded panes show glyph + title.
FORMAT="#{?pane_format,${GLYPH}#{pane_title},#{?window_format,#{P:${GLYPH}}#W #[fg=cyan]#{pane_title}#[default],#S}}"

# Only show windows containing at least one agent pane (#{P:...} concatenates
# every pane's state; empty means no agent). Sessions always shown.
FILTER='#{?pane_format,#{!=:#{@herd_state},},#{?window_format,#{!=:#{P:#{@herd_state}},},1}}'

# prefix + g (configurable via @herd-popup-key) opens the agent popup.
# Set @herd-popup 'native' for a choose-tree instead (zero process spawns,
# same machinery as prefix+s, but plainer looks).
popup_key="$(get_opt @herd-popup-key)"
popup_key="${popup_key:-g}"
if [ "$(get_opt @herd-popup)" = "native" ]; then
  tmux bind-key "$popup_key" choose-tree -Z -F "$FORMAT" -f "$FILTER"
else
  tmux bind-key "$popup_key" display-popup -E -w 70% -h 60% "$CURRENT_DIR/scripts/popup.sh"
fi

status_cmd="#($CURRENT_DIR/scripts/statusline.sh)"

# If the user placed a #{herd_status} placeholder, substitute it in place.
placeholder_found=0
for opt in status-left status-right; do
  val="$(tmux show-option -gqv "$opt")"
  if [[ "$val" == *"#{herd_status}"* ]]; then
    tmux set-option -g "$opt" "${val//"#{herd_status}"/$status_cmd}"
    placeholder_found=1
  fi
done

# Zero-config default: prepend to status-right once.
if [[ "$placeholder_found" -eq 0 ]]; then
  val="$(tmux show-option -gqv status-right)"
  if [[ "$val" != *tmux-herd* ]]; then
    tmux set-option -g status-right "$status_cmd $val"
  fi
fi
