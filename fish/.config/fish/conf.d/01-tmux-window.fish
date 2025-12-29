function __rename_tmux_window --on-variable PWD --description 'Change the tmux window to the current git directory name'
  # Only proceed if in tmux
  if test -z "$TMUX"
    return
  end

  # Don't change window name if a custom name was set
  set tmux_win_id (tmux display-message -p "#I")
  set tmux_custom_win_name (tmux show-environment | grep "^tmux_win_$tmux_win_id")
  if test $status -eq 0
    return
  end

  # Git repo: show parent/repo name
  git rev-parse --is-inside-work-tree &>/dev/null
  if test $status -eq 0
    set repo_path (git rev-parse --show-toplevel)
    set repo_name (basename $repo_path)
    set repo_parent (basename (dirname $repo_path))
    tmux rename-window "$repo_parent/$repo_name"
  end
end
