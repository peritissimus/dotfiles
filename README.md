# My Setup (Mac)

1. **Install Homebrew:**
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Install iTerm2:**
   ```bash
   brew install --cask iterm2
   ```

3. **Install Fish**
   ```bash
   brew install fish
   ```

4. **Set fish as default shell**
   ```bash
   sudo bash -c 'echo /opt/homebrew/bin/fish >> /etc/shells'
   ```

8. **Install Node.js, Python, Rust, and Go:**
   For Node.js, it's recommended to use nvm (Node Version Manager) to manage Node.js versions. For Python, Rust, and Go, you can use Homebrew.

   ```bash
   brew install node
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   brew install go
   ```

7. **Install jq, fzf, ripgrep:**

   ```bash
   brew install jq fzf ripgrep
   ```

5. **Install Fisher and Tide (Fish plugins) and Z:**
   ```bash
   curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
   fisher install IlanCosman/tide
   fisher install jethrokuan/z
   ```

4. **Install Neovim, Fish, and Tmux:**
   ```bash
   brew install neovim tmux
   ```

6. **Clone Dotfiles:**

   ```bash
   git clone git@github.com:peritissimus/dotfiles.git
   ```

7. **Symlink Dotfiles**
   ```bash
   ln -s ~/dotfiles/tmux/.tmux.conf ~/.tmux.conf
   ln -s ~/dotfiles/nvim ~/.config/nvim
   ln -s ~/dotfiles/fish/config.fish ~/.config/fish/config.fish
   ```

8. **Setup Tmux**
   ```bash
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   tmux source ~/.tmux.conf
   ```


9. **Install Flutter along with VSCode, Rosetta 2, Android SDK, and Emulators:**
   Follow the official Flutter installation guide, which includes setting up VSCode, Rosetta 2, Android SDK, and Emulators.
    ```bash
    brew install --cask visual-studio-code
    ```

10. **Install Raycast:**

    ```bash
    brew install --cask raycast
    ```

11. **Install Rectangle:**
    ```bash
    brew install --cask rectangle
    ```
