#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

STOW_ONLY=0
STOW_DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --stow-only) STOW_ONLY=1 ;;
    --dry-run) STOW_ONLY=1; STOW_DRY_RUN=1 ;;
    -h|--help)
      echo "Usage: $0 [--stow-only | --dry-run]"
      echo "  --stow-only  Link dotfiles without installing packages, tools, or plugins."
      echo "  --dry-run    Preview dotfile links without changing anything."
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

DOTFILES_SERVER=(
  bash
  bat
  codex
  eza
  fish
  gh
  git
  glow
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
  docker/tap/sbx
  fish
  fisher
  htop
  lua
  orbstack
  postgresql
  stow
  tmux
  tree
  universal-ctags
)

BREW_TAPS=(
  docker/tap
)

BREW_CASKS=(
  alt-tab
  monitorcontrol
  ngrok
  rectangle
)

APT_PACKAGES=(
  build-essential
  docker-sbx
  git
  htop
  lua5.4
  make
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

install_git_repo() {
  local repo_url="$1"
  local commit="$2"
  local install_dir="$3"

  [[ -e "$install_dir" ]] && return

  git clone --no-checkout "$repo_url" "$install_dir" &&
    git -C "$install_dir" checkout --detach "$commit"
}

stow_dotfiles() {
  local pkg
  local stow_args=(--verbose)
  local failed_packages=()

  if ! command -v stow &> /dev/null; then
    echo "GNU Stow is required to link dotfiles." >&2
    return 1
  fi

  if [[ "${STOW_ADOPT:-0}" == "1" ]]; then
    stow_args+=(--adopt)
  fi
  if [[ "$STOW_DRY_RUN" == "1" ]]; then
    stow_args+=(--simulate)
  fi

  for pkg in "${DOTFILES[@]}"; do
    if [[ ! -d "$SCRIPT_DIR/$pkg" ]]; then
      echo "Missing stow package: $pkg" >&2
      failed_packages+=("$pkg")
      continue
    fi

    if ! stow --dir "$SCRIPT_DIR" --target "$HOME" "${stow_args[@]}" "$pkg"; then
      failed_packages+=("$pkg")
    fi
  done

  if ((${#failed_packages[@]})); then
    echo "Failed to stow: ${failed_packages[*]}" >&2
    echo "Resolve the conflicts above, then rerun $0 --stow-only." >&2
    return 1
  fi
}

DOTFILES=("${DOTFILES_SERVER[@]}")
if is_desktop; then
  DOTFILES+=("${DOTFILES_DESKTOP[@]}")
fi

if [[ "$STOW_ONLY" == "1" ]]; then
  stow_dotfiles
  exit $?
fi

# Install packages
if is_macos; then
  # Install Homebrew if not installed
  if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Update Homebrew
  brew update

  # Trust taps
  for tap in "${BREW_TAPS[@]}"; do
    brew trust "$tap"
  done

  # Install packages
  brew install --quiet "${BREW_PACKAGES[@]}"

  # Install casks
  brew install --quiet --cask "${BREW_CASKS[@]}"
fi

if is_linux; then
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common

  sudo apt-add-repository -y ppa:fish-shell/release-4
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

# Install tmux plugins
TMUX_PLUGINS_DIR="$HOME/.tmux/plugins"
mkdir -p "$TMUX_PLUGINS_DIR"
install_git_repo \
  https://github.com/tmux-plugins/tmux-resurrect.git \
  cff343cf9e81983d3da0c8562b01616f12e8d548 \
  "$TMUX_PLUGINS_DIR/tmux-resurrect"
install_git_repo \
  https://github.com/tmux-plugins/tmux-continuum.git \
  0698e8f4b17d6454c71bf5212895ec055c578da0 \
  "$TMUX_PLUGINS_DIR/tmux-continuum"

# Install Mise
if ! command -v mise &> /dev/null; then
  curl -fsSL https://mise.run | sh
fi

# Get mise executable path 
MISE_BIN="$HOME/.local/bin/mise"
if [[ ! -x "$MISE_BIN" ]]; then
  MISE_BIN="$(command -v mise || true)"
fi

# Setup mise shims
if [[ -n "$MISE_BIN" ]]; then
  mise_bin_dir="$(dirname "$MISE_BIN")"
  case ":$PATH:" in
    *":$mise_bin_dir:"*) ;;
    *) export PATH="$mise_bin_dir:$PATH" ;;
  esac
else
  echo "Mise not found in PATH or ~/.local/bin; expected mise to be installed." >&2
  exit 1
fi

# Stow dotfiles before installing tools that depend on their configuration.
stow_dotfiles || exit 1

# Install Mise tools
export MISE_CONFIG_FILE="$SCRIPT_DIR/mise/.config/mise/config.toml"
MISE_JOBS=1 "$MISE_BIN" install

# Disable go telemetry
if "$MISE_BIN" exec -- which go &> /dev/null; then
  "$MISE_BIN" exec -- go telemetry off
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
