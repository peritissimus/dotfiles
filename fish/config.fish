# Remove fish greeting
set fish_greeting

# Environment variables
set -gx EDITOR nvim

# Homebrew setup
eval "$(/opt/homebrew/bin/brew shellenv)"

# NVM setup
set -x NVM_DIR ~/.nvm
function nvm
    bass source (brew --prefix nvm)/nvm.sh --no-use ';' nvm $argv
end

# Go setup
set -x GOPATH $HOME/go
set -x PATH $GOPATH/bin $PATH

# Flutter setup
set -x PATH /Users/peritissimus/development/flutter/bin $PATH

# Android setup
set -x PATH /Users/peritissimus/Library/Android/sdk/platform-tools $PATH

# Python/Pyenv setup
set -Ux PYENV_ROOT $HOME/.pyenv
set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths
pyenv init - | source

# Other PATH additions
set -gx PATH $HOME/.gem/bin $PATH
set -x PATH $PATH $HOME/.pub-cache/bin
set -x PATH /usr/local/bin $PATH

# Aliases
alias startenv=". .venv/bin/activate.fish"
alias lz="lazygit"
alias mux="tmuxinator"
alias timelygit='GIT_SSH_COMMAND="ssh -i ~/.ssh/timely_key" git'

# LSD configuration (if installed)
if type -q lsd
    alias ll "lsd -Al"
    alias llt "lsd -A --tree"
end

# Interactive session commands
if status is-interactive
    # Commands to run in interactive sessions can go here
end
