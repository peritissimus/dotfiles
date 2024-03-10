# My Setup (Mac)

1. **Install Git and Homebrew:**

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Install iTerm2:**

   ```bash
   brew install --cask iterm2
   ```

3. **Configure Colors for iTerm2:**
   You can manually configure colors within iTerm2 preferences.

4. **Install Neovim, Fish, and Tmux:**

   ```bash
   brew install neovim fish tmux
   ```

5. **Install Fisher and Tide (Fish plugins) and Z:**

   ```bash
   curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
   fisher install IlanCosman/tide
   brew install z
   ```

6. **Clone Dotfiles:**

   ```bash
   git clone <dotfiles_repo_url> ~/.dotfiles
   ```

7. **Install jq, fzf, ripgrep:**

   ```bash
   brew install jq fzf ripgrep
   ```

8. **Install Node.js, Python, Rust, and Go:**
   For Node.js, it's recommended to use nvm (Node Version Manager) to manage Node.js versions. For Python, Rust, and Go, you can use Homebrew.

   ```bash
   brew install node
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   brew install go
   ```

9. **Install Flutter along with VSCode, Rosetta 2, Android SDK, and Emulators:**
   Follow the official Flutter installation guide, which includes setting up VSCode, Rosetta 2, Android SDK, and Emulators.

10. **Install Raycast:**

    ```bash
    brew install --cask raycast
    ```

11. **Install Rectangle:**
    ```bash
    brew install --cask rectangle
    ```
