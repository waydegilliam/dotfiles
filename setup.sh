#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

DOTFILES_SERVER=(
  bash
  bat
  claude
  eza
  fish
  git
  ipython
  lazygit
  mise
  npm
  nvim
  prettier
  ruff
  scripts
  stylua
  tmux
)

DOTFILES_DESKTOP=(
  code
  cursor
  ghostty
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

is_desktop() {
  if is_macos; then
    return 0
  fi

  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == "x11" || "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    return 0
  fi

  if command -v loginctl &> /dev/null && [[ -n "${XDG_SESSION_ID:-}" ]]; then
    if loginctl show-session "$XDG_SESSION_ID" -p Type 2>/dev/null | grep -Eq 'Type=(x11|wayland)'; then
      return 0
    fi
  fi

  return 1
}

# Install packages
if is_macos; then
  DOTFILES=("${DOTFILES_SERVER[@]}" "${DOTFILES_DESKTOP[@]}")
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
  DOTFILES=("${DOTFILES_SERVER[@]}")
  if is_desktop; then
    DOTFILES+=("${DOTFILES_DESKTOP[@]}")
  fi
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common

  sudo apt-add-repository ppa:fish-shell/release-4
  sudo apt update
  sudo apt install -y fish

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
  curl -fsSL https://mise.run | sh
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
  stow_args=()
  if [[ "${STOW_ADOPT:-0}" == "1" ]]; then
    stow_args+=(--adopt)
  fi

  for pkg in "${stow_packages[@]}"; do
    if [[ "$pkg" == "fish" && -e "$HOME/.config/fish" ]]; then
      backup_path="/tmp/fish-config-backup-$(date +%Y%m%d%H%M%S)"
      echo "Backing up existing fish config to $backup_path"
      mv "$HOME/.config/fish" "$backup_path"
    fi

    if ! stow --dir "$SCRIPT_DIR" --target "$HOME" "${stow_args[@]}" "$pkg"; then
      echo "Skipping stow package $pkg (conflicts or errors)"
    fi
  done
fi

# Install Mise tools
if [[ -n "$MISE_BIN" ]]; then
  mise_config="$HOME/.config/mise/config.toml"
  if [[ -f "$SCRIPT_DIR/mise/.config/mise/config.toml" && ! -f "$mise_config" ]]; then
    MISE_CONFIG_FILE="$SCRIPT_DIR/mise/.config/mise/config.toml"
    export MISE_CONFIG_FILE
  fi
  MISE_JOBS=1 "$MISE_BIN" install
else
  echo "Mise not found in PATH or ~/.local/bin; expected mise to be installed." >&2
  exit 1
fi

# Configure Fish shell
if command -v fish &> /dev/null; then
  fish -c "type -q fisher; or curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
  fish_plugins=(
    jorgebucaran/fisher
    jethrokuan/z
    patrickf1/fzf.fish
    IlanCosman/tide@v6
  )
  fish -c "fisher install ${fish_plugins[*]}"
  fish -c "fish_vi_key_bindings"
else
  echo "Fish not found in PATH; expected fish to be installed." >&2
  exit 1
fi

# Silence Unix login message
if is_macos; then
  touch ~/.hushlogin
fi
