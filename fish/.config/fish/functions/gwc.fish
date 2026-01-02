function gwc --description "Checkout a git worktree"
  set -l worktrees (git worktree list)

  # Change into a specified worktree
  if test -n "$argv[1]"
    for line in $worktrees
      set -l branch (string match -rg '\[(.+)\]' -- $line)
      if test "$branch" = "$argv[1]"
        set -l worktree_path (string split -f1 ' ' -- $line)
        cd "$worktree_path"
        return 0
      end
    end

    echo "No worktree found for branch: $argv[1]"
    return 1

  # Change into a fuzzy searched worktree
  else
    set -l height (math (count $worktrees) + 2)
    set -l formatted
    for line in $worktrees
      set -l path (string split -f1 ' ' -- $line)
      set -l branch (string match -rg '\[(.+)\]' -- $line)
      set -a formatted "$path:::$branch"
    end

    set -l selected (printf '%s\n' $formatted | fzf --height=$height --delimiter=':::' --with-nth=2)
    set -l worktree_path (string split -f1 ':::' -- $selected)

    if test -n "$worktree_path"
      cd "$worktree_path"
    end
  end
end
