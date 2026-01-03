function gwa --description "Add a git worktree"
  if test -z "$argv[1]"
    echo "Usage: gwa [branch name]"
    return 1
  end

  set -lx GIT_MAIN_WORKTREE_PATH (git worktree list --porcelain | head -n 1 | string replace 'worktree ' '')
  set -l repo_name (basename $GIT_MAIN_WORKTREE_PATH)
  set -l repo_default_branch (git symbolic-ref refs/remotes/origin/HEAD --short | sed 's@origin/@@')

  set -lx GIT_WORKTREE_BRANCH "$argv[1]"
  set -lx GIT_WORKTREE_PATH "$(dirname "$GIT_MAIN_WORKTREE_PATH")/$repo_name--$GIT_WORKTREE_BRANCH"

  # Run pre-create hook
  if set -q GIT_WORKTREE_PRE_CREATE
    eval $GIT_WORKTREE_PRE_CREATE
    or return 1
  end

  # Create worktree
  git worktree add -b "$GIT_WORKTREE_BRANCH" "$GIT_WORKTREE_PATH" "$repo_default_branch"
  or return 1

  # Run post-create hook
  if set -q GIT_WORKTREE_POST_CREATE
    eval $GIT_WORKTREE_POST_CREATE
    or echo "Warning: post-create hook failed"
  end

  mise trust "$GIT_WORKTREE_PATH"
  cd "$GIT_WORKTREE_PATH"
end

