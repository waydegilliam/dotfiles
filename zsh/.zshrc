# ===== General ===============================================================

# Disable bell sound
unsetopt BEEP

# Initialize completions
fpath=(~/.zfunc $fpath)
autoload -Uz compinit && compinit -i

# Setup history file
HISTFILE=~/.zsh_history
setopt appendhistory

# ===== Environment Variables =================================================

export PATH="/opt/homebrew/bin:$PATH"
export ZSH_PLUGIN_PATH=$HOME/.local/share/zsh/plugins

# ===== Functions =============================================================

function zsh_source_plugin() {
    [ -f "$ZSH_PLUGIN_PATH/$1" ] && source "$ZSH_PLUGIN_PATH/$1"
}

function zsh_add_plugin() {
    PLUGIN_NAME=$(echo $1 | cut -d "/" -f 2)
    if [ -d "$ZSH_PLUGIN_PATH/$PLUGIN_NAME" ]; then 
        zsh_source_plugin "$PLUGIN_NAME/$PLUGIN_NAME.plugin.zsh" || \
        zsh_source_plugin "$PLUGIN_NAME/$PLUGIN_NAME.zsh"
    else
        git clone "https://github.com/$1.git" "$ZSH_PLUGIN_PATH/$PLUGIN_NAME" 
    fi
}

# ===== Plugins ===============================================================

zsh_add_plugin "zsh-users/zsh-autosuggestions"
zsh_add_plugin "zsh-users/zsh-history-substring-search"
zsh_add_plugin "zsh-users/zsh-syntax-highlighting"

# ===== Keybinds ==============================================================

# Search history
bindkey "^p" up-line-or-search
bindkey "^n" down-line-or-search

# Search history in Vi mode
bindkey -M vicmd "k" history-substring-search-up
bindkey -M vicmd "j" history-substring-search-down

# "Backward Tab"
bindkey '^[[Z' reverse-menu-complete

# ===== Aliases ===============================================================

alias ls="ls -p -G"
alias la="ls -A"
alias ll="exa -l -g --icons"
alias ll="exa -l -g --icons"
alias lla="ll -a"
alias tree="tree -l -C -a"

alias g=git
alias gs="git status"
alias ga="git add"
alias gd="git diff"
alias gc="git commit -m"

alias t=tmux
alias ts="tmux ls"
alias ta="tmux attach -t"
alias tk="tmux kill-session -t"

alias cat=bat
alias d=docker
alias vim=nvim
alias nvm=fnm

# ===== Setup =================================================================

# Setup FNM
eval "$(fnm env --use-on-cd)"

# Setup Zoxide
eval "$(zoxide init zsh)"

