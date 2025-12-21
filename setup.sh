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

  available_packages=()
  for pkg in "${APT_PACKAGES[@]}"; do
    if apt-cache show "$pkg" 2>/dev/null | grep -q '^Package:'; then
      available_packages+=("$pkg")
    else
      echo "Skipping $pkg (not in apt for this Ubuntu release)"
    fi
  done

  if ((${#available_packages[@]})); then
    sudo apt install -y "${available_packages[@]}"
  fi

  if apt-cache show docker-ce 2>/dev/null | grep -q '^Package:'; then
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || \
      echo "Skipping Docker CE install due to apt conflicts."
  elif apt-cache show docker.io 2>/dev/null | grep -q '^Package:'; then
    sudo apt install -y docker.io
  else
    echo "Skipping Docker install (no docker packages in apt sources)"
  fi
fi

# Install Mise
if ! command -v mise &> /dev/null; then
  curl https://mise.run | MISE_VERSION="$MISE_VERSION" sh
fi

MISE_BIN="$(command -v mise || true)"
if [[ -z "$MISE_BIN" && -x "$HOME/.local/bin/mise" ]]; then
  MISE_BIN="$HOME/.local/bin/mise"
fi

# Stow dotfiles
stow_packages=()
for pkg in "${DOTFILES[@]}"; do
  if [[ -d "$SCRIPT_DIR/$pkg" ]]; then
    stow_packages+=("$pkg")
  else
    echo "Skipping stow package $pkg (directory missing)"
  fi
done

if ((${#stow_packages[@]})); then
  stow --dir "$SCRIPT_DIR" --target "$HOME" "${stow_packages[@]}"
fi

# Install Mise tools
if [[ -n "$MISE_BIN" ]]; then
  "$MISE_BIN" install
else
  echo "Skipping mise install (mise not found in PATH or ~/.local/bin)"
fi

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
