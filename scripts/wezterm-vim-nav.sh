#!/usr/bin/env bash
# WezTerm + Vim navigation helper
# This script helps vim-tmux-navigator work with WezTerm

direction=$1

# Check if we're in tmux
if [ -n "$TMUX" ]; then
    # Use tmux navigation
    case $direction in
        left)  tmux select-pane -L ;;
        down)  tmux select-pane -D ;;
        up)    tmux select-pane -U ;;
        right) tmux select-pane -R ;;
    esac
else
    # Use WezTerm CLI navigation
    case $direction in
        left)  wezterm cli activate-pane-direction Left ;;
        down)  wezterm cli activate-pane-direction Down ;;
        up)    wezterm cli activate-pane-direction Up ;;
        right) wezterm cli activate-pane-direction Right ;;
    esac
fi