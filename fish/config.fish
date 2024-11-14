set fish_greeting

eval "$(/opt/homebrew/bin/brew shellenv)"

alias startenv=". .venv/bin/activate.fish"
alias lz="lazygit"
alias mux="tmuxinator"
alias timelygit='GIT_SSH_COMMAND="ssh -i ~/.ssh/timely_key" git'

set -gx EDITOR nvim

set -x GOPATH $HOME/go
set -x PATH $GOPATH/bin $PATH
set -x PATH $PATH $HOME/.pub-cache/bin
set -gx PATH $HOME/.gem/bin $PATH

if status is-interactive
    # Commands to run in interactive sessions can go here
end


if type -q lsd
    alias ll "lsd -Al"
    alias llt "lsd -A --tree"
end

set -x PATH /Users/peritissimus/development/flutter/bin $PATH

set -x NVM_DIR ~/.nvm
bass source (brew --prefix nvm)/nvm.sh

set -x PATH /Users/peritissimus/Library/Android/sdk/platform-tools $PATH
