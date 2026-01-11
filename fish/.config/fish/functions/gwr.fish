function gwr --description "Remove a git worktree"
  set -l current_path (pwd)
  set -l main_worktree_path (git worktree list --porcelain | head -n 1 | string replace 'worktree ' '')

  set -l worktree_branch
  if test -n "$argv[1]"
    set worktree_branch "$argv[1]"
  else
    set -l worktrees (git worktree list)
    set -l formatted
    for line in $worktrees
      set -l path (string split -f1 ' ' -- $line)
      if test "$path" = "$main_worktree_path"
        continue
      end
      set -l folder (basename $path)
      set -l branch (string match -rg '\[(.+)\]' -- $line)
      set -a formatted "$branch:::"(printf "%-30s %s" $folder $branch)
    end

    if test (count $formatted) -eq 0
      echo "No worktrees to remove"
      return 1
    end

    set -l height (math (count $formatted) + 2)
    set -l selected (printf '%s\n' $formatted | fzf --height=$height --delimiter=':::' --with-nth=2)
    if test -z "$selected"
      return 0
    end
    set worktree_branch (string split -f1 ':::' -- $selected)
  end
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
