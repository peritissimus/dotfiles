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

# Function to install package based on OS
install_package() {
  local package=$1
  local apt_package=${2:-$package}  # Use second arg for apt name if different

  case "$OS" in
  "Darwin")
    install_brew_package "$package"
    ;;
  "Linux")
    if command_exists apt-get; then
      if ! dpkg -l | grep -q "^ii  $apt_package "; then
        log "Installing $apt_package..."
        sudo apt-get update -qq && sudo apt-get install -y "$apt_package"
        success "$apt_package installed successfully!"
      else
        success "$apt_package is already installed"
      fi
    elif command_exists dnf; then
      if ! rpm -q "$apt_package" >/dev/null 2>&1; then
        log "Installing $apt_package..."
        sudo dnf install -y "$apt_package"
        success "$apt_package installed successfully!"
      else
        success "$apt_package is already installed"
      fi
    elif command_exists pacman; then
      if ! pacman -Q "$apt_package" >/dev/null 2>&1; then
        log "Installing $apt_package..."
        sudo pacman -S --noconfirm "$apt_package"
        success "$apt_package installed successfully!"
      else
        success "$apt_package is already installed"
      fi
    else
      error "No supported package manager found (apt/dnf/pacman)"
      return 1
    fi
    ;;
  *)
    error "Unsupported OS: $OS"
    return 1
    ;;
  esac
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

# Package manager setup based on OS
if [ "$OS" = "Darwin" ]; then
  install_homebrew
elif [ "$OS" = "Linux" ]; then
  log "Using system package manager for Linux"
  if command_exists apt-get; then
    sudo apt-get update -qq
  fi
fi

# Install required packages (OS-agnostic with package name mapping)
log "Installing required packages..."

# Format: "brew_name:apt_name:dnf_name:pacman_name" (use same name if identical across distros)
# Using a simple array instead of associative array for bash 3.2 compatibility
PACKAGES=(
  "fish:fish:fish:fish"
  "node:nodejs:nodejs:nodejs"
  "go:golang-go:golang:go"
  "jq:jq:jq:jq"
  "yq:yq:yq:yq"
  "fzf:fzf:fzf:fzf"
  "ripgrep:ripgrep:ripgrep:ripgrep"
  "gh:gh:gh:github-cli"
  "xh:xh:xh:xh"
  "neovim:neovim:neovim:neovim"
  "tmux:tmux:tmux:tmux"
  "zellij:zellij:zellij:zellij"
  "lazygit:lazygit:lazygit:lazygit"
  "lazydocker:lazydocker:lazydocker:lazydocker"
  "git-delta:git-delta:git-delta:git-delta"
  "atuin:atuin:atuin:atuin"
  "bat:bat:bat:bat"
  "eza:eza:eza:eza"
  "fd:fd-find:fd-find:fd"
  "btop:btop:btop:btop"
  "broot:broot:broot:broot"
  "zoxide:zoxide:zoxide:zoxide"
  "starship:starship:starship:starship"
)

for package_spec in "${PACKAGES[@]}"; do
  # Initialize variables to avoid unbound variable errors
  brew="" apt="" dnf="" pacman=""
  IFS=':' read -r brew apt dnf pacman <<< "$package_spec"

  case "$OS" in
  "Darwin")
    install_package "$brew"
    ;;
  "Linux")
    if command_exists apt-get; then
      install_package "$apt" "$apt"
    elif command_exists dnf; then
      install_package "$dnf" "$dnf"
    elif command_exists pacman; then
      install_package "$pacman" "$pacman"
    fi
    ;;
  esac
done

# macOS-specific packages
if [ "$OS" = "Darwin" ]; then
  # Raycast (macOS only)
  install_brew_package "raycast"

  # Install cask packages
  log "Installing cask packages..."
  if ! brew list --cask "wezterm" >/dev/null 2>&1; then
    log "Installing wezterm..."
    brew install --cask "wezterm"
    success "wezterm installed successfully!"
  else
    success "wezterm is already installed"
  fi
fi

# Set Fish as default shell (OS-aware)
FISH_PATH=""
if [ "$OS" = "Darwin" ]; then
  FISH_PATH="/opt/homebrew/bin/fish"
elif [ "$OS" = "Linux" ]; then
  FISH_PATH="$(command -v fish)"
fi

if [ -n "$FISH_PATH" ] && command_exists fish; then
  if ! grep -q "$FISH_PATH" /etc/shells; then
    log "Adding Fish to /etc/shells..."
    echo "$FISH_PATH" | sudo tee -a /etc/shells
    success "Fish added to /etc/shells"
  fi

  if [ "$SHELL" != "$FISH_PATH" ]; then
    log "Setting Fish as default shell..."
    if chsh -s "$FISH_PATH" 2>/dev/null; then
      success "Fish set as default shell"
    else
      warn "Could not set Fish as default shell (requires password). Run 'chsh -s $FISH_PATH' manually."
    fi
  fi
fi

# Install Rust (OS-agnostic)
if ! command_exists rustc; then
  log "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  success "Rust installed successfully!"
else
  success "Rust is already installed"
fi

# Setup Fisher (OS-agnostic, requires Fish)
if command_exists fish; then
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
fi

# Install Nerd Fonts (commented out but kept for reference)
# log "Checking Nerd Fonts..."
# MESLO_FILES=("MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf")
# FIRA_FILES=("FiraCode Regular Nerd Font Complete.ttf" "FiraCode Bold Nerd Font Complete.ttf")
# ... (font installation code)

# Create common symlinks
log "Setting up Alacritty..."
create_symlink "$DOTFILES_DIR/alacritty" "$CONFIG_HOME/alacritty"

log "Setting up Ghostty..."
create_symlink "$DOTFILES_DIR/ghostty/config" "$CONFIG_HOME/ghostty/config"

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

log "Setting up Zellij..."
create_symlink "$DOTFILES_DIR/zellij/config.kdl" "$CONFIG_HOME/zellij/config.kdl"

log "Setting up WezTerm..."
create_symlink "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.wezterm.lua"

log "Setting up Eza..."
create_symlink "$DOTFILES_DIR/eza" "$CONFIG_HOME/eza"

log "Setting up Claude..."
create_symlink "$DOTFILES_DIR/claude" "$HOME/.claude"

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
