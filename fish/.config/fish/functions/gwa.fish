function _gwa_name_from_pr --argument-names pr_number
  gh pr view $pr_number --json headRefName -q .headRefName
end

function _gwa_name_from_branch --argument-names branch_name
  echo $branch_name
end

function _gwa_setup --argument-names branch_name
  set -gx GIT_MAIN_WORKTREE_PATH (git worktree list --porcelain | head -n 1 | string replace 'worktree ' '')
  set -g _gwa_repo_name (basename $GIT_MAIN_WORKTREE_PATH)
  set -gx GIT_WORKTREE_BRANCH "$branch_name"
  set -gx GIT_WORKTREE_PATH "$(dirname "$GIT_MAIN_WORKTREE_PATH")/$_gwa_repo_name--$GIT_WORKTREE_BRANCH"
end

function _gwa_finish
  if set -q GIT_WORKTREE_POST_CREATE
    eval $GIT_WORKTREE_POST_CREATE
    or echo "Warning: post-create hook failed"
  end

  mise trust "$GIT_WORKTREE_PATH"
  cd "$GIT_WORKTREE_PATH"
end

function gwa --description "Add a git worktree"
  argparse 'p/pr=' 'b/branch=' -- $argv
  or return 1

  set -l branch_name
  set -l checkout_existing false

  if set -q _flag_pr
    set branch_name (_gwa_name_from_pr $_flag_pr)
    or begin
      echo "Error: Could not get branch name for PR #$_flag_pr"
      return 1
    end
    set checkout_existing true

  else if set -q _flag_branch
    set branch_name (_gwa_name_from_branch $_flag_branch)
    set checkout_existing true

  else
    if test -z "$argv[1]"
      echo "Usage: gwa <branch name> [base branch]"
      echo "       gwa --pr <pr number>"
      echo "       gwa --branch <branch name>"
      return 1
    end
    set branch_name "$argv[1]"
  end

  _gwa_setup "$branch_name"

  if set -q GIT_WORKTREE_PRE_CREATE
    eval $GIT_WORKTREE_PRE_CREATE
    or return 1
  end

  if test "$checkout_existing" = true
    git fetch origin +"$GIT_WORKTREE_BRANCH":"$GIT_WORKTREE_BRANCH"
    or return 1

    git worktree add "$GIT_WORKTREE_PATH" "$GIT_WORKTREE_BRANCH"
    or return 1
  else
    set -l repo_default_branch (git symbolic-ref refs/remotes/origin/HEAD --short | sed 's@origin/@@')
    set -l base_branch $repo_default_branch
    if test -n "$argv[2]"
      set base_branch "$argv[2]"
    end

    git worktree add -b "$GIT_WORKTREE_BRANCH" "$GIT_WORKTREE_PATH" "$base_branch"
    or return 1
  end

  _gwa_finish
end
