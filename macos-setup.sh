#!/usr/bin/env bash

# ----- Install packages ---------------------------------------------------------------

# Install homebrew packages
brew install bat direnv docker docker-compose eza fd fish fnm fx fzf ghq go hatch htop \
  jq lua node pandoc pipx pyenv ripgrep stow \
  stylua tmux tree universal-ctags yarn saulpw/vd/visidata git-delta wget gh groff \
  postgresql

# Install homebrew casks
brew install --casks ngrok alt-tab

# Install neovim
wget https://github.com/neovim/neovim/releases/download/v0.9.4/nvim-macos.tar.gz -P ~/Downloads
xattr -c ~/Downloads/nvim-macos.tar.gz
sudo tar xzvf ~/Downloads/nvim-macos.tar.gz -C /opt

# Install (global) npm packages
sudo npm install -g \ 
  @taplo/cli@0.5.2 \
  prettier@2.8.0 \
  @trivago/prettier-plugin-sort-imports@4.0.0 \
  sql-formatter

# Install bun
curl -fsSL https://bun.sh/install | bash



# ----- Setup Fish Shell ---------------------------------------------------------------

# Install Fisher (plugin manager)
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"

# Remove conflicting fish files (in preparation for Stow)
rm ~/.config/fish/config.fish ~/.config/fish/functions/fish_mode_prompt.fish

# Stow fish
stow -d $HOME/ghq/github.com/waydegg/dotfiles-public -t $HOME fish

# Install plugins
fish -c "fisher update"

# Setup completions
_HATCH_COMPLETE=fish_source hatch > ~/.config/fish/completions/hatch.fish

# ----- Setup Neovim ----------------------------------------------------------

# Install vim-plug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Install language servers
npm install -g \
  pyright \
  typescript-language-server \
  vim-language-server \
  vscode-langservers-extracted \
  vls
brew install lua-language-server rust-analyzer


# ----- Final steps -----------------------------------------------------------

# Remove conflicting fish files (in preparation for Stow)
rm ~/.config/fish/config.fish ~/.config/fish/functions/fish_mode_prompt.fish

# Stow everything
stow -d $HOME/ghq/github.com/waydegilliam/dotfiles -t $HOME \
  bat direnv fish git ipython npm nvim stylua tmux

# Enable vi mode for fish
fish -c "fish_vi_key_bindings"

# Setup neovim venv (TODO: test that this works)
~/.pyenv/versions/3.10.4/bin/python -m venv ~/.config/nvim/venv
~/.config/nvim/venv/bin/pip install -r ~/.config/nvim/requirements.txt

# Silence login message
touch ~/.hushlogin

# Reboot
sudo reboot

