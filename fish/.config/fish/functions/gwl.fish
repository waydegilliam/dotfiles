function gwl --description "List all git worktrees"
  set -l current (git rev-parse --show-toplevel)
  set -l worktrees (git worktree list)

  for line in $worktrees
    set -l path (string split -f1 ' ' -- $line)
    set -l folder (basename $path)
    set -l branch (string match -rg '\[(.+)\]' -- $line)

    set -l prefix "  "
    if test "$path" = "$current"
      set prefix "* "
    end

    printf "%s%-30s %s\n" $prefix $folder $branch
  end
end
