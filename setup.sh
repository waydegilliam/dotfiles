#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MISE_VERSION="v2025.12.20"

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
  mise
  npm
  nvim
  ruff
  scripts
  stylua
  tmux
  vimium
)

BREW_PACKAGES=(
  docker
  fish
  fisher
  htop
  orbstack
  postgresql
  stow
  tmux
  tree
  universal-ctags
)

BREW_CASKS=(
  alt-tab
  monitorcontrol
  ngrok
  rectangle
)

APT_PACKAGES=(
  docker.io
  fish
  git
  htop
  postgresql
  postgresql-contrib
  stow
  tmux
  tree
  universal-ctags 
  unzip
)

is_macos() {
  [[ "$OSTYPE" == "darwin"* ]]
}

is_linux() {
  [[ "$OSTYPE" == "linux"* ]]
}

# Install packages
if is_macos; then
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

if is_linux; then
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg lsb-release

  for pkg in "${APT_PACKAGES[@]}"; do
    if apt-cache show "$pkg" 2>/dev/null | grep -q '^Package:'; then
      sudo apt install -y "$pkg"
    else
      echo "Skipping $pkg (not in apt for this Ubuntu release)"
    fi
  done
fi

# Install Mise
curl https://mise.run | sh 

# Stow dotfiles
stow --dir $SCRIPT_DIR --target $HOME "${DOTFILES[@]}"

# Install Mise tools
mise install

# Configure Fish shell
if command -v fish &> /dev/null; then
  fish -c "type -q fisher; or curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
  fish -c "fisher update"
  fish -c "fish_vi_key_bindings"
fi

# Silence Unix login message
if is_macos; then
  touch ~/.hushlogin
fi
