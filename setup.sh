#!/bin/bash

# Exit on error
set -e

# Define colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where the script is located
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}Setting up dotfiles...${NC}"

# Install Nerd Fonts
echo -e "\n${BLUE}Installing Nerd Fonts...${NC}"
FONT_DIR="$HOME/Library/Fonts"
MESLO_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Meslo.zip"
FIRA_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FiraCode.zip"

# Function to download and install font
install_font() {
    local font_url=$1
    local font_name=$2
    
    echo "Downloading $font_name..."
    TEMP_DIR=$(mktemp -d)
    curl -L "$font_url" -o "$TEMP_DIR/$font_name.zip"
    
    echo "Installing $font_name..."
    unzip -o "$TEMP_DIR/$font_name.zip" -d "$FONT_DIR" >/dev/null 2>&1
    rm -rf "$TEMP_DIR"
    echo -e "${GREEN}$font_name installed successfully!${NC}"
}

# Install both fonts
install_font "$MESLO_URL" "Meslo"
install_font "$FIRA_URL" "FiraCode"

# Function to create symlink
create_symlink() {
    local src=$1
    local dest=$2
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$dest")"
    
    # Remove existing file/symlink if it exists
    if [ -e "$dest" ]; then
        echo "Removing existing $dest"
        rm -rf "$dest"
    fi
    
    # Create symlink
    ln -s "$src" "$dest"
    echo -e "${GREEN}Created symlink:${NC} $src → $dest"
}

# Alacritty
echo -e "\n${BLUE}Setting up Alacritty...${NC}"
create_symlink "$DOTFILES_DIR/alacritty" "$HOME/.config/alacritty"

# Neovim
echo -e "\n${BLUE}Setting up Neovim...${NC}"
create_symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

# Fish
echo -e "\n${BLUE}Setting up Fish...${NC}"
create_symlink "$DOTFILES_DIR/fish/config.fish" "$HOME/.config/fish/config.fish"

# Tmux
echo -e "\n${BLUE}Setting up Tmux...${NC}"
create_symlink "$DOTFILES_DIR/tmux" "$HOME/.tmux.conf"

# Tmuxinator
echo -e "\n${BLUE}Setting up Tmuxinator...${NC}"
create_symlink "$DOTFILES_DIR/tmuxinator" "$HOME/.config/tmuxinator"

# # Scripts
# echo -e "\n${BLUE}Setting up Scripts...${NC}"
# create_symlink "$DOTFILES_DIR/scripts" "$HOME/.local/bin"

# Raycast
echo -e "\n${BLUE}Setting up Raycast...${NC}"
create_symlink "$DOTFILES_DIR/raycast" "$HOME/.config/raycast"

# iTerm2 (Note: iTerm2 colors need to be imported manually through the UI)
echo -e "\n${BLUE}Note: iTerm2 colors need to be imported manually through iTerm2 preferences${NC}"

echo -e "\n${GREEN}Dotfiles setup complete!${NC}"

# Make scripts executable
echo -e "\n${BLUE}Making scripts executable...${NC}"
# chmod +x "$HOME/.local/bin/pr.sh"
# chmod +x "$HOME/.local/bin/commit.sh"
# chmod +x "$DOTFILES_DIR/art.sh"
# chmod +x "$DOTFILES_DIR/spotify.sh"

echo -e "\n${GREEN}All done! 🎉${NC}"
echo -e "${BLUE}Note: You may need to restart your terminal or applications to see the new fonts.${NC}"
