# Dotfiles

My personal dotfiles for setting up a development environment on macOS and Linux. These configurations focus on creating a productive and aesthetically pleasing terminal-based workflow.

![ScreenShotSetup](https://raw.githubusercontent.com/peritissimus/dotfiles/main/setup-screenshot.png)

## Features

- **Terminal**: Configured with Alacritty for performance and Fish shell for user-friendliness
- **Editor**: Neovim setup with LSP support and modern plugins
- **Multiplexer**: Tmux configuration with Tmuxinator profiles
- **Window Management**: Aerospace for macOS, i3 for Linux
- **Productivity**: Raycast scripts and custom utilities

## Prerequisites

- Git
- macOS or Linux
- Homebrew (for macOS)

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/dotfiles.git
   cd dotfiles
   ```

2. Make the setup script executable:
   ```bash
   chmod +x setup.sh
   ```

3. Run the setup script:
   ```bash
   ./setup.sh
   ```

The setup script will:
- Install required packages via Homebrew (macOS)
- Set up Fish shell as default
- Install development tools (Node.js, Python, Rust, Go)
- Install and configure terminal utilities
- Create necessary symlinks
- Install Nerd Fonts (Meslo and FiraCode)

## Key Components

### Shell (Fish)
- Configured with Fisher package manager
- Includes Tide prompt
- Z for directory jumping
- Custom functions and aliases

### Terminal (Alacritty)
- Hardware-accelerated terminal emulator
- Configured for optimal performance
- Custom color schemes
- Proper font rendering

### Editor (Neovim)
- Modern Neovim configuration in Lua
- LSP support for various languages
- Treesitter for better syntax highlighting
- Lazy.nvim for plugin management
- Custom keybindings and settings

### Window Management
- **macOS**: Aerospace for tiling window management
- **Linux**: i3 window manager configuration

### Terminal Multiplexer (Tmux)
- Custom status line
- Keybindings for efficient pane/window management
- Tmuxinator profiles for project-specific layouts

### Development Tools
- Node.js environment
- Rust toolchain
- Go development setup
- Python environment
- Various CLI utilities (ripgrep, fzf, jq, etc.)

## Directory Structure
```
dotfiles
├── setup.sh                # Main setup script
├── alacritty/             # Alacritty terminal configuration
├── nvim/                  # Neovim configuration
│   ├── init.lua
│   └── lua/              # Lua configuration files
├── fish/                  # Fish shell configuration
├── tmux/                  # Tmux configuration
├── tmuxinator/            # Tmuxinator project profiles
├── aerospace/             # Aerospace (macOS) configuration
├── i3/                    # i3 (Linux) configuration
└── raycast/               # Raycast scripts and commands
```

## Customization

### Adding New Configurations
1. Create a new directory for your configuration
2. Add the configuration files
3. Update `setup.sh` to include the new symlinks

### Modifying Existing Configurations
- Each tool's configuration is contained in its respective directory
- Configuration files are extensively commented for easy modification
- The setup script can be re-run after making changes

## Maintenance

To update all tools and configurations:

1. Pull the latest changes:
   ```bash
   git pull origin main
   ```

2. Re-run the setup script:
   ```bash
   ./setup.sh
   ```

## Contributing

Feel free to fork this repository and customize it for your needs. If you make improvements that might be useful to others, please submit a pull request.

## Acknowledgments

These dotfiles are inspired by and include configurations from various sources:
- [LazyVim](https://github.com/LazyVim/LazyVim)
- [Fish Shell](https://fishshell.com/)
- [Alacritty](https://github.com/alacritty/alacritty)
- Various community configurations and best practices

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
