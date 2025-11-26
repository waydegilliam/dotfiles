#!/usr/bin/env sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

DOTFILES=(
  bash
  bat
  claude
  cursor
  eza
  fish
  ghostty
  git
  ipython
  karabiner
  npm
  nvim
  ruff
  scripts
  stylua
  tmux
  vimium
)

BREW_PACKAGES=(
  bat
  docker
  docker-compose
  eza
  fd
  fish
  fisher
  fnm
  fx
  fzf
  gh
  ghq
  git-delta
  go
  htop
  jq
  lua
  lua-language-server
  neovim
  orbstack
  postgresql
  ripgrep
  rust-analyzer
  stow
  stylua
  tmux
  tree
  universal-ctags
  yarn
)

BREW_CASKS=(
  alt-tab
  monitorcontrol
  ngrok
  rectangle
)

# Install Macos packages
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Install Homebrew if not installed
    if ! command -v brew &> /dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Update Homebrew
    brew update

    # Install packages
    brew install --quiet "${BREW_PACKAGES[@]}"

    # Install casks
    brew install --quiet --cask "${BREW_CASKS[@]}"
fi

# Install Bun
curl -fsSL https://bun.sh/install | bash > /dev/null

# Install uv tools
uv tool install ruff

# Stow dotfiles
stow --dir $SCRIPT_DIR --target $HOME "${DOTFILES[@]}"

# Configure Fish shell
fish -c "fisher update"
fish -c "fish_vi_key_bindings"

# Silence Unix login message
touch ~/.hushlogin
