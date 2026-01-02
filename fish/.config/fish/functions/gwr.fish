function gwr --description "Remove a git worktree"
  if test -z "$argv[1]"
    echo "Usage: gwr [branch name]"
    return 1
  end

  set -l worktree_branch "$argv[1]"
  set -l worktree_line (git worktree list | grep -E "\[$worktree_branch\]")

  if test -z "$worktree_line"
    echo "No worktree found for branch: $worktree_branch"
    return 1
  end

  set -l worktree_path (echo "$worktree_line" | awk '{print $1}')
  set -l repo_path (git worktree list --porcelain | head -n 1 | string replace 'worktree ' '')

  if not test -f "$worktree_path/.git"
    echo "Not a linked worktree: $worktree_path"
    return 1
  end

  read -l -P "Remove worktree and branch '$worktree_branch'? [y/N] " confirm
  or return

  if string match -qi "y" $confirm
    set -l worktree_is_cwd (string match -q "$worktree_path*" "$PWD"; and echo "yes"; or echo "no")
    if test "$worktree_is_cwd" = "yes"
      cd "$repo_path"
    end

    git worktree remove "$worktree_path"
    git branch -D "$worktree_branch"
  end
end
