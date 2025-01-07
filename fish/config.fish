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


set -x ANDROID_HOME $HOME/Library/Android/sdk # Mac

set -x PATH $PATH $ANDROID_HOME/tools
set -x PATH $PATH $ANDROID_HOME/tools/bin
set -x PATH $PATH $ANDROID_HOME/platform-tools
set -x PATH $PATH $ANDROID_HOME/emulator


# Java/Jenv setup (single source of truth)
set -gx JENV_ROOT "$HOME/.jenv"
set -gx JAVA_HOME (jenv javahome)
set -gx PATH "$JENV_ROOT/bin" $PATH
status --is-interactive; and jenv init - fish | source

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
alias c2p="code2prompt"
alias timelygit='GIT_SSH_COMMAND="ssh -i ~/.ssh/timely_key" git'

# LSD configuration (if installed)
if type -q lsd
    alias ll "lsd -Al"
    alias llt "lsd -A --tree"
end

status --is-interactive; and source (jenv init -|psub)
