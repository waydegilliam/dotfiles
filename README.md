# Dotfiles

Personal dotfiles for macOS and Ubuntu.

## Setup

Keep the checkout in its final location, then run:

```sh
./setup.sh              # Install packages and link dotfiles
./setup.sh --dry-run    # Preview links without changes
./setup.sh --stow-only  # Link dotfiles without installing tools
```

Stow packages mirror paths under `~`: `fish/.config/fish` links to `~/.config/fish`.
Stow individual packages, not the whole checkout (`stow -t "$HOME" .`).

Codex config lives in `~/.config/codex`, with compatibility links in `~/.codex`.
