set fish_greeting

# Group environment variables together
set -gx EDITOR nvim
set -gx JAVA_HOME (bash -c "/opt/homebrew/opt/openjdk@17/bin/java -XshowSettings:properties -version 2>&1 | grep 'java.home' | awk '{print \$3}'")
set -gx PATH $HOME/.gem/bin $PATH

# Development tools setup
## Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

## Docker
set -gx DOCKER_HOST "unix://$HOME/.colima/default/docker.sock"

## NVM (Node Version Manager)
set -gx NVM_DIR ~/.nvm
function nvm
    bass source $NVM_DIR/nvm.sh --no-use ';' nvm $argv
end

# Load default node version on shell startup
if test -s "$NVM_DIR/nvm.sh"
    bass source $NVM_DIR/nvm.sh --no-use ';' nvm use default
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

## Other paths
fish_add_path /usr/local/bin $HOME/.pub-cache/bin
set -gx CPPFLAGS "-I/opt/homebrew/opt/openjdk@17/include"
set -x PATH $HOME/.cargo/bin $PATH

# Initialize zoxide
zoxide init fish | source

# Initialize starship
starship init fish | source

# Initialize atuin
atuin init fish | source

# bat configuration
set -gx BAT_THEME "Dracula"

# eza configuration
set -gx EZA_CONFIG_DIR "$HOME/.config/eza"


# Aliases (grouped by functionality)
## Development tools
alias startenv=". .venv/bin/activate.fish"
alias lz="lazygit"
alias ld="lazydocker"
alias tf="terraform"
alias mux="tmuxinator"
alias c2p="code2prompt"
alias gcm="~/dotfiles/scripts/gcm.sh"
alias qdays="~/dotfiles/scripts/qdays.sh"
alias pf="~/dotfiles/scripts/prettier.sh"

## Git-related
alias timelygit='GIT_SSH_COMMAND="ssh -i ~/.ssh/timely_key" git'

## Project-specific
alias linear="npm run dev --"

## Modern CLI tool replacements
alias cat="bat"
alias find="fd"
alias ls="eza"
alias ll="eza -l"
alias la="eza -la"
alias tree="eza --tree"

alias monopgcli="PGPASSWORD=mononest pgcli -h postgres.mononest.local -p 5433 -U mononest -d mononest_dev"

function update_pr --description "Update PR description with AI-generated summary"
    set pr_number $argv[1]
    
    if test -z "$pr_number"
        echo "Please provide a PR number"
        return 1
    end
    
    # Generate the PR summary
    ~/dotfiles/scripts/gpr.sh $pr_number
    
    # Update the PR with the generated summary
    gh pr edit $pr_number --body-file pr_summary_$pr_number.md
    
    echo "PR #$pr_number description updated successfully!"
end
set -gx PATH $PATH /opt/homebrew/Cellar/tmuxinator/3.3.3/libexec

# Garmin Connect IQ SDK
set -x PATH $PATH "/Users/peritissimus/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.2.0-2025-05-27-67ddf1dcb/bin"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH



