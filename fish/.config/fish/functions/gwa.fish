function gwa --description "Add a git worktree"
  if test -z "$argv[1]"
    echo "Usage: gwa [branch name]"
    return 1
  end

  set -l repo_path (git worktree list --porcelain | head -n 1 | string replace 'worktree ' '')
  set -l repo_name (basename $repo_path)
  set -l repo_default_branch (git symbolic-ref refs/remotes/origin/HEAD --short | sed 's@origin/@@')

  set -l worktree_branch "$argv[1]"
  set -l worktree_path "$(dirname "$repo_path")/$repo_name--$worktree_branch"

  git worktree add -b "$worktree_branch" "$worktree_path" "$repo_default_branch"
  mise trust "$worktree_path"
  cd "$worktree_path"
end

