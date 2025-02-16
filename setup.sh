#!/usr/bin/env bash

# Exit on error
set -euo pipefail

# Define colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where the script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Homebrew if it's not already installed
install_homebrew() {
    if ! command_exists brew; then
        log "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        success "Homebrew installed successfully!"
    else
        success "Homebrew is already installed"
    fi
}

# Function to install a Homebrew package if it's not already installed
install_brew_package() {
    local package=$1
    if ! brew list "$package" >/dev/null 2>&1; then
        log "Installing $package..."
        brew install "$package"
        success "$package installed successfully!"
    else
        success "$package is already installed"
    fi
}

# Function to download and install font
install_font() {
    local font_url=$1
    local font_name=$2
    
    log "Downloading $font_name..."
    TEMP_DIR=$(mktemp -d)
    curl -L "$font_url" -o "$TEMP_DIR/$font_name.zip"
    
    log "Installing $font_name..."
    unzip -o "$TEMP_DIR/$font_name.zip" -d "$FONT_DIR" >/dev/null 2>&1
    rm -rf "$TEMP_DIR"
    success "$font_name installed successfully!"
}

# Function to create symlink
create_symlink() {
    local src="$1"
    local dest="$2"
    
    # Check if source exists
    if [ ! -e "$src" ]; then
        error "Source file/directory does not exist: $src"
        return 1
    fi
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$dest")"
    
    # Remove existing file/symlink if it exists
    if [ -e "$dest" ]; then
        log "Removing existing $dest"
        rm -rf "$dest"
    fi
    
    # Create symlink
    ln -sf "$src" "$dest"
    success "Created symlink: $src → $dest"
}

# Detect operating system
OS="$(uname -s)"
case "$OS" in
    "Darwin")
        CONFIG_HOME="$HOME/.config"
        FONT_DIR="$HOME/Library/Fonts"
        ;;
    "Linux")
        CONFIG_HOME="$HOME/.config"
        FONT_DIR="$HOME/.local/share/fonts"
        ;;
    *)
        error "Unsupported operating system: $OS"
        exit 1
        ;;
esac

log "Setting up dotfiles..."

# macOS-specific setup
if [ "$OS" = "Darwin" ]; then
    # Install Homebrew
    install_homebrew

    # Install required packages
    log "Installing required packages..."
    PACKAGES=(
        "fish"
        "node"
        "go"
        "jq"
        "fzf"
        "ripgrep"
        "gh"
        "xh"
        "neovim"
        "tmux"
        "raycast"
        "lazygit"
        "lazydocker"
        "git-delta"
        "atuin"
        "bat"
        "fd"
        "btop"
        "broot"
        "zoxide"
        "starship"
    )

    for package in "${PACKAGES[@]}"; do
        install_brew_package "$package"
    done

    # Set Fish as default shell if it isn't already
    if ! grep -q "/opt/homebrew/bin/fish" /etc/shells; then
        log "Adding Fish to /etc/shells..."
        echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
        success "Fish added to /etc/shells"
    fi

    if [ "$SHELL" != "/opt/homebrew/bin/fish" ]; then
        log "Setting Fish as default shell..."
        chsh -s /opt/homebrew/bin/fish
        success "Fish set as default shell"
    fi

    # Install Rust
    if ! command_exists rustc; then
        log "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        success "Rust installed successfully!"
    else
        success "Rust is already installed"
    fi

    # Clean up existing Fisher plugins
    if [ -f "$HOME/.config/fish/functions/fisher.fish" ]; then
        log "Removing existing Fisher plugins..."
        fish -c 'fisher list | fisher remove'
        success "Cleaned up Fisher plugins"
    fi

    # Install/Reinstall Fisher
    log "Installing Fisher..."
    fish -c 'curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher'
    success "Fisher installed successfully!"

    # Install core Fisher plugins
    log "Installing Fisher plugins..."
    fish -c 'fisher install edc/bass'
    success "Fisher plugins installed successfully!"

    # Install Nerd Fonts if not present
    log "Checking Nerd Fonts..."

    # Define font files to check (common font files from these packages)
    MESLO_FILES=("MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf")
    FIRA_FILES=("FiraCode Regular Nerd Font Complete.ttf" "FiraCode Bold Nerd Font Complete.ttf")

    # Check Meslo
    MESLO_INSTALLED=true
    for font in "${MESLO_FILES[@]}"; do
        if [ ! -f "$FONT_DIR/$font" ]; then
            MESLO_INSTALLED=false
            break
        fi
    done

    # Check FiraCode
    FIRA_INSTALLED=true
    for font in "${FIRA_FILES[@]}"; do
        if [ ! -f "$FONT_DIR/$font" ]; then
            FIRA_INSTALLED=false
            break
        fi
    done

    # Install only missing fonts
    MESLO_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Meslo.zip"
    FIRA_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FiraCode.zip"

    # if [ "$MESLO_INSTALLED" = false ]; then
    #     log "Installing Meslo Nerd Font..."
    #     install_font "$MESLO_URL" "Meslo"
    # else
    #     success "Meslo Nerd Font is already installed"
    # fi
    #
    # if [ "$FIRA_INSTALLED" = false ]; then
    #     log "Installing FiraCode Nerd Font..."
    #     install_font "$FIRA_URL" "FiraCode"
    # else
    #     success "FiraCode Nerd Font is already installed"
    # fi
fi

# Create common symlinks
log "Setting up Alacritty..."
create_symlink "$DOTFILES_DIR/alacritty" "$CONFIG_HOME/alacritty"

log "Setting up Neovim..."
create_symlink "$DOTFILES_DIR/nvim" "$CONFIG_HOME/nvim"

log "Setting up Fish..."
create_symlink "$DOTFILES_DIR/fish/config.fish" "$CONFIG_HOME/fish/config.fish"

log "Setting up Tmux..."
create_symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

log "Setting up Starship..."
create_symlink "$DOTFILES_DIR/starship/starship.toml" "$CONFIG_HOME/starship.toml"

log "Setting up Tmuxinator..."
create_symlink "$DOTFILES_DIR/tmuxinator" "$CONFIG_HOME/tmuxinator"

# OS-specific symlinks
if [ "$OS" = "Darwin" ]; then
    log "Setting up macOS-specific configurations..."
    
    # Raycast
    create_symlink "$DOTFILES_DIR/raycast" "$CONFIG_HOME/raycast"
    
    # Aerospace
    create_symlink "$DOTFILES_DIR/aerospace/aerospace.toml" "$CONFIG_HOME/aerospace/aerospace.toml"

elif [ "$OS" = "Linux" ]; then
    log "Setting up Linux-specific configurations..."
    
    # i3
    create_symlink "$DOTFILES_DIR/i3/config" "$CONFIG_HOME/i3/config"
fi

success "Dotfiles setup complete! 🎉"
log "Note: You may need to restart your terminal to apply all changes."
