# ===== Environment Variables =================================================
# Disable Fish greeting
set fish_greeting ""

# Set default editor to Neovim
set -x EDITOR nvim

# Tide prompt
set -g tide_git_color_branch 008700
set -g tide_git_color_stash 008700
set -g tide_git_color_untracked 008700
set -g tide_character_color 008700
set -g tide_character_vi_icon_default ❯
set -g tide_character_vi_icon_replace ❯
set -g tide_character_vi_icon_visual ❯
set -g tide_right_prompt_items status cmd_duration context jobs python

# Set IPython directory
set -x IPYTHONDIR $HOME/.config/ipython

# Rustup and Cargo config directories, add Cargo to PATH
set -x RUSTUP_HOME $HOME/.config/rustup
set -x CARGO_HOME $HOME/.config/cargo
set -x PATH $HOME/.config/cargo/bin $PATH

# direnv
set -x DIRENV_LOG_FORMAT ""

# Add $HOME/.local/bin to path (pipx puts executables here)
set -x PATH $HOME/.local/bin $PATH

# pip
set -x PIP_DISABLE_PIP_VERSION_CHECK 1

# Use bat for manpager 
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

switch (uname)
  case Darwin
    # brew
    set -x PATH /opt/homebrew/bin $PATH
    set -x HOMEBREW_NO_ENV_HINTS 1

    # lazygit needs this explicitly specified
    set -x XDG_CONFIG_HOME $HOME/.config

    # nvim
    set -x PATH /opt/nvim-macos/bin $PATH

    # vscode
    set -x PATH /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin $PATH

    # psql
    fish_add_path /opt/homebrew/opt/postgresql@16/bin/psql

    # eza
    set -x EZA_CONFIG_DIR $HOME/.config/eza

    # karabiner cli
    set -x PATH /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin $PATH

  case Linux
    # Add nvim to $PATH
    set -x PATH /opt/nvim-linux64/bin $PATH

    # Add pyenv to $PATH
    set -x PATH $HOME/.pyenv/bin $PATH

    # Cuda stuff
    set -x PATH /usr/local/cuda-11.3/bin $PATH
    set -x LD_LIBRARY_PATH /usr/local/cuda-11.3/lib64 $LD_LIBRARY_PATH
end

# Add bun to PATH
set -x PATH $HOME/.bun/bin $PATH


# ===== Aliases ================================================================
alias ls "ls -p -G"
alias la "ls -A"
alias ll "eza --long --group --group-directories-first --icons"
alias lla "ll --all"
alias tree "tree -l -C -a -I '.git' -I 'venv' -I '__pycache__' -I '*.egg-info' -I '*.ipynb_checkpoints' -I 'node_modules'"

alias g git
alias gs "git status"
alias ga "git add"
alias gb "git branch"
alias gbl "git branch --list"
alias gbd "git branch --delete"
alias gd "git diff"
alias gds "git diff --staged"
alias gc "git commit"
alias gcm "git commit -m"
alias gci "git commit -m '.'"
alias gsl "git stash list"
alias gw "git worktree"
alias gwa "git worktree add"
alias gwl "git worktree list"
alias gwr "git worktree remove"

alias t tmux
alias ts "tmux ls"
alias tk "tmux kill-session -t"
alias tks "tmux kill-server"

alias p python
alias python python3
alias pip "python -m pip"
alias wp "which python"
alias ipy ipython

alias d docker
alias dc docker-compose
alias dcl "docker ps -a"
alias dcp "docker container prune"
alias di "docker image"
alias dil "docker image ls"
alias dv "docker volume"
alias dvl "docker volume ls"
alias dn "docker network"
alias dnl "docker network ls"

alias uvr "uv run"

alias cat bat
alias nvm fnm
alias vim nvim
alias vi nvim
alias c clear
alias logout exit
alias watch-gpu "watch -n0.1 nvidia-smi"
alias lg lazygit
alias claude="/Users/waydegilliam/.claude/local/claude"

switch (uname)
  case Darwin
    alias speedtest "networkQuality -v"
  case Linux
    alias speedtest "speedtest-cli"
end


# ===== Keybinds ==============================================================
# Search through command history
bind -M insert \cp history-search-backward
bind -M insert \cn history-search-forward

# Exit insert mode 
bind -M insert -m default jk force-repaint

# ===== Auto-running Functions ================================================
function __check_venv --on-variable PWD --description 'Source venv (if exists) on directory change'
  status --is-command-substitution; and return
  if test -d venv
    source ./venv/bin/activate.fish
  else if test -d .venv
    source ./.venv/bin/activate.fish
  end
end

function __rename_tmux_window --on-variable PWD --description 'Change the tmux window to the current git directory name'
  git rev-parse --is-inside-work-tree &>/dev/null
  if test $status -eq 0 && test -n "$TMUX"

    # Don't change window name if a custom name was set
    set tmux_win_id (tmux display-message -p "#I") 
    set tmux_custom_win_name (tmux show-environment | grep "^tmux_win_$tmux_win_id")
    if test $status -eq 0 
      return
    end

    set repo_path (git rev-parse --show-toplevel)
    set repo_name (basename $repo_path)
    tmux rename-window $repo_name
  end
end

# ===== Tool setup ============================================================
# fnm
if type fnm -q && status is-interactive 
  fnm env --shell fish --use-on-cd | source
end

# pyenv
pyenv init - | source

# direnv
direnv hook fish | source

# venv
set -e VIRTUAL_ENV
if test -d venv
  source ./venv/bin/activate.fish
end

