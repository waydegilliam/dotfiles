function gwm --description "Merge a worktree into the default branch"
  # Get current location and branch info
  set -l current_path (pwd)
  set -l main_worktree_path (git worktree list --porcelain | head -n 1 | string replace 'worktree ' '')
  set -l current_branch (git branch --show-current)

  # Must run from a worktree, not the main repo
  if test "$current_path" = "$main_worktree_path"
    echo "Error: Already on main worktree. Run from a feature worktree."
    return 1
  end

  # Require clean working directory to prevent losing uncommitted work
  if not git diff --quiet || not git diff --cached --quiet
    echo "Error: Uncommitted changes in worktree. Commit or stash first."
    return 1
  end

  # Confirm before proceeding
  read -l -P "Merge and remove worktree '$current_branch'? [y/N] " confirm
  or return

  if not string match -qi "y" $confirm
    return 0
  end

  # Switch to main worktree and checkout default branch
  cd "$main_worktree_path"
  set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD --short | sed 's@origin/@@')
  git checkout $default_branch
  or begin
    cd "$current_path"
    return 1
  end

  # Apply changes as unstaged modifications
  git diff $default_branch..$current_branch | git apply
  or begin
    cd "$current_path"
    return 1
  end

  # Clean up the worktree and its branch
  git worktree remove "$current_path"
  git branch -D "$current_branch"
end
