set fish_greeting

# Enable vi mode for command line editing
fish_vi_key_bindings

# Group environment variables together
set -gx EDITOR nvim
set -gx JAVA_HOME (bash -c "/opt/homebrew/opt/openjdk@17/bin/java -XshowSettings:properties -version 2>&1 | grep 'java.home' | awk '{print \$3}'")
set -gx PATH $HOME/.gem/bin $PATH

set -gx OPENAI_API_KEY (security find-generic-password -a "$USER" -s "OPENAI_API_KEY" -w 2>/dev/null)
set -gx CLOUDFLARE_API_TOKEN (security find-generic-password -a "$USER" -s "cloudflare-api-token" -w 2>/dev/null)
set -gx CLOUDFLARE_ACCOUNT_ID (security find-generic-password -a "$USER" -s "cloudflare-account-id" -w 2>/dev/null)
set -gx NX_TUI false
# Development tools setup
## Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"
# Ensure Homebrew bash (5.x) is used before system bash (3.2)
fish_add_path --prepend /opt/homebrew/bin

## Dotfiles scripts
# Framework path for bash-oo-framework (used by scripts)
set -gx BASH_OO_FRAMEWORK "$HOME/dotfiles/scripts/lib"
# Add scripts to PATH so they're available as commands
fish_add_path "$HOME/dotfiles/scripts"

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
alias tt="tmux a -t"
alias ts="tmux new -s"
alias c2p="code2prompt"
alias yz='yazi'

## Dotfiles scripts (available via PATH, aliases for convenience/shorter names)
alias pf="prettier"           # Run prettier on git modified files

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

## Obsidian
function obs --description "Open a file in Obsidian vault 'NoteBook'"
    if test (count $argv) -eq 0
        echo "Usage: obs <file_path>"
        return 1
    end

    set file_path $argv[1]
    open "obsidian://open?vault=NoteBook&file=$file_path"
end

set -gx PATH $PATH /opt/homebrew/Cellar/tmuxinator/3.3.3/libexec

# Garmin Connect IQ SDK
set -x PATH $PATH "/Users/peritissimus/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.2.0-2025-05-27-67ddf1dcb/bin"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH




# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/peritissimus/.lmstudio/bin
# End of LM Studio CLI section


# Added by Antigravity
fish_add_path /Users/peritissimus/.antigravity/antigravity/bin

set -gx PATH "/opt/homebrew/opt/postgresql@16/bin" $PATH

function envsource
    for line in (cat $argv | grep -v '^#' | grep -v '^$')
        set item (string split -m 1 '=' $line)
        set -gx $item[1] $item[2]
    end
end

# opencode
fish_add_path /Users/peritissimus/.opencode/bin
