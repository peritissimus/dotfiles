set fish_greeting

eval "$(/opt/homebrew/bin/brew shellenv)"

alias startenv=". .venv/bin/activate.fish"
alias lz="lazygit"
alias mux="tmuxinator"

set -gx EDITOR nvim

set -x GOPATH $HOME/go
set -x PATH $GOPATH/bin $PATH

if status is-interactive
    # Commands to run in interactive sessions can go here
end


if type -q lsd
    alias ll "lsd -Al"
    alias llt "lsd -A --tree"
end

set -x PATH /Users/peritissimus/development/flutter/bin $PATH
