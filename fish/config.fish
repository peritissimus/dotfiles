# Place at the top since it affects everything below
set fish_greeting

# Group environment variables together
set -gx EDITOR nvim
set -gx JAVA_HOME (/opt/homebrew/opt/openjdk@17/bin/java -XshowSettings:properties -version 2>&1 > /dev/null | grep 'java.home' | awk '{print $3}')
set -gx PATH $HOME/.gem/bin $PATH

# Development tools setup
## Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

## NVM (consider using fnm instead - it's faster)
set -gx NVM_DIR ~/.nvm
function nvm
    bass source (brew --prefix nvm)/nvm.sh --no-use ';' nvm $argv
end

## Go
set -gx GOPATH $HOME/go
fish_add_path $GOPATH/bin

## Flutter and Android
set -gx ANDROID_HOME $HOME/Library/Android/sdk
fish_add_path /Users/peritissimus/development/flutter/bin \
    $ANDROID_HOME/tools \
    $ANDROID_HOME/tools/bin \
    $ANDROID_HOME/platform-tools \
    $ANDROID_HOME/emulator


fish_add_path /opt/homebrew/opt/coreutils/libexec/gnubin

## Python
set -Ux PYENV_ROOT $HOME/.pyenv
fish_add_path $PYENV_ROOT/bin
pyenv init - | source

## Other paths
fish_add_path /usr/local/bin $HOME/.pub-cache/bin

set -gx CPPFLAGS "-I/opt/homebrew/opt/openjdk@17/include"

set -x PATH $HOME/.cargo/bin $PATH
# Aliases (grouped by functionality)
## Development tools
alias startenv=". .venv/bin/activate.fish"
alias lz="lazygit"
alias tf="terraform"
alias mux="tmuxinator"
alias c2p="code2prompt"
alias gcm="~/dotfiles/scripts/gcm.sh"

## Git-related
alias timelygit='GIT_SSH_COMMAND="ssh -i ~/.ssh/timely_key" git'

## Project-specific
alias linear="npm run dev --"

## File listing
if type -q lsd
    alias ll "lsd -Al"
    alias llt "lsd -A --tree"
end

