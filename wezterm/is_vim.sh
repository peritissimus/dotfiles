#!/usr/bin/env bash
# Check if current pane is running vim
pane_tty="${1:-$(tmux display -p '#{pane_tty}')}"
ps -o state= -o comm= -t "$pane_tty" | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'