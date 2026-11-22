# A fish-native replacement for x-motemen/ghq. Repositories live at
# <root>/<owner>/<repo>, where root is $GHQ_ROOT or ~/development. The host is
# not part of the path, so the same owner/repo from two hosts is a conflict
function ghq --description "Manage git repositories under ~/development/<owner>/<repo>"
  set -l cmd $argv[1]
  set -l rest $argv[2..]

  switch "$cmd"
    case get clone
      __ghq_get $rest
    case list ls
      __ghq_list $rest
    case cd
      __ghq_cd $rest
    case rm
      __ghq_rm $rest
    case create
      __ghq_create $rest
    case root
      __ghq_root
    case __preview
      __ghq_preview $rest
    case '' help -h --help
      __ghq_usage
    case '*'
      echo "ghq: unknown command '$cmd' (see 'ghq help')" >&2
      return 1
  end
end

function __ghq_usage
  echo "usage: ghq <command> [args]

  get [-u] <repo>...        Clone into the root. -u pulls repos that already exist;
                            with no repo, -u opens a picker of repos to update
  list [-p] [-e] [query]    List repos. -p prints full paths, -e matches exactly
  cd [query]                Jump to a repo, picking with fzf when ambiguous
  rm [query]                Delete a repo after confirmation
  create <repo>             Create and git init a new repo, then cd into it
  root                      Print the root directory

<repo> is a URL, host/owner/repo, owner/repo, or repo (your own on github.com).
Repos are stored at <root>/<owner>/<repo> whatever the host"
end

function __ghq_root
  if set -q GHQ_ROOT; and test -n "$GHQ_ROOT"
    string trim --right --chars=/ -- $GHQ_ROOT
  else
    echo $HOME/development
  end
end

# Prints every repo under the root, relative to it. A directory holding .git is
# a repo and is never descended into, so nested checkouts and node_modules are
# never walked
function __ghq_repos
  set -l root (__ghq_root)
  set -l repos
  set -l level $root/*/

  for depth in 1 2 3 4 5
    test (count $level) -gt 0; or break
    set -l markers $level.git
    set -a repos (path filter -- $markers | path dirname)
    set -l parents (path filter --invert -- $markers | path dirname)
    set level $parents/*/
  end

  test (count $repos) -gt 0; or return 0
  string replace -- "$root/" '' $repos | path sort
end

# __ghq_filter exact|contains <query> <repo>...
# "exact" matches the whole path or its trailing components (repo, owner/repo).
# "contains" is a substring match, case-insensitive unless the query has capitals
function __ghq_filter --argument-names mode query
  set -l repos $argv[3..]
  test (count $repos) -gt 0; or return 0

  if test "$mode" = exact
    for repo in $repos
      if test "$repo" = "$query"; or string match -q -- "*/$query" $repo
        echo $repo
      end
    end
    return 0
  end

  set -l flags --entire
  string match -q -r '[A-Z]' -- $query; or set -a flags --ignore-case
  string match $flags -- "*$query*" $repos
  return 0
end

# Prints four lines for a repo spec: path relative to the root (owner/repo),
# clone URL, "url" or "shorthand" depending on how the spec was written, and host
function __ghq_parse --argument-names spec
  set -l spec (string trim --right --chars=/ -- $spec)
  set -l host
  set -l repo_path
  set -l url
  set -l kind url

  if set -l m (string match -r '^[A-Za-z][A-Za-z0-9+.-]*://(?:[^@/]+@)?([^/:]+)(?::\d+)?/(.+)$' -- $spec)
    set host $m[2]
    set repo_path $m[3]
    set url $spec
  else if set -l m (string match -r '^(?:[^@/]+@)?([^/:]+):(.+)$' -- $spec)
    set host $m[2]
    set repo_path $m[3]
    set url $spec
  else
    set kind shorthand
    set -l parts (string split / -- $spec)
    if test (count $parts) -ge 3; and string match -q -- '*.*' $parts[1]
      set host $parts[1]
      set repo_path (string join / -- $parts[2..])
    else if test (count $parts) -eq 2
      set host github.com
      set repo_path $spec
    else if test (count $parts) -eq 1; and test -n "$spec"
      set -l user (git config --get ghq.user 2>/dev/null)
      test -n "$user"; or set user $GITHUB_USER
      test -n "$user"; or set user $USER
      set host github.com
      set repo_path $user/$spec
    end
    set url https://$host/$repo_path
  end

  set repo_path (string replace -r '\.git$' '' -- $repo_path | string trim --chars=/)

  if test -z "$host" -o -z "$repo_path"
    or string match -q -- '-*' $spec
    or contains -- .. (string split / -- $repo_path)
    or string match -q -- '*/*' $host
    echo "ghq: cannot parse repo '$argv[1]'" >&2
    return 1
  end

  echo $repo_path
  echo $url
  echo $kind
  echo $host
end

# Prints "<host>/<owner>/<repo>" for the origin remote of a checkout, or
# nothing when it has no origin
function __ghq_origin --argument-names dir
  set -l url (git -C $dir remote get-url origin 2>/dev/null)
  test -n "$url"; or return 0
  set -l parsed (__ghq_parse $url 2>/dev/null); or return 0
  echo $parsed[4]/$parsed[1]
end

# Prints "<status> <text>" with the status coloured, for one-line results
function __ghq_report --argument-names kind text
  switch $kind
    case cloned updated created removed
      set_color green
    case failed
      set_color red
    case '*'
      set_color brblack
  end
  echo -n (string pad --right --width 10 -- $kind)
  set_color normal
  echo $text
end

# Dims the leading directories of each repo path and bolds the repo name
function __ghq_colorize
  string replace -r '^(.*/)?([^/]+)$' (set_color brblack)'$1'(set_color normal)(set_color --bold)'$2'(set_color normal) -- $argv
end

# Opens fzf over every repo, most recently active first, and prints the
# selection. The first arg is the starting query; the rest go to fzf
function __ghq_pick --argument-names query
  set -l fzf _fzf_wrapper
  type -q $fzf; or set fzf fzf
  if not type -q $fzf
    echo "ghq: fzf is required to pick a repo" >&2
    return 1
  end

  set -l root (__ghq_root)
  set -l repos (__ghq_repos)
  if test (count $repos) -eq 0
    echo "ghq: no repos under $root" >&2
    return 1
  end

  # git touches .git on nearly every operation, so its mtime tracks activity
  set repos (command ls -dt -- $root/$repos/.git | string replace -- "$root/" '' | string replace -r '/\.git$' '')

  set -l shown (__ghq_colorize $repos)

  set -l rows
  for i in (seq (count $repos))
    set -a rows $repos[$i]\t$shown[$i]
  end

  set -l picked (string join \n -- $rows | $fzf \
    --ansi \
    --delimiter=\t \
    --with-nth=2 \
    --scheme=path \
    --tiebreak=index \
    --query="$query" \
    --preview="ghq __preview "(string escape -- $root)"/{1}" \
    --preview-window=right,55% \
    $argv[2..])
  or return 1

  string split -f1 \t -- $picked
end

function __ghq_preview --argument-names dir
  test -d "$dir"; or return 1

  set -l remote (git -C $dir remote get-url origin 2>/dev/null)
  if test -n "$remote"
    set_color brblack; echo $remote; set_color normal
  end
  git -C $dir -c color.status=always status --short --branch 2>/dev/null | head -n 12
  echo
  git -C $dir log -n 5 --color=always \
    --format='%C(yellow)%h%C(reset) %s %C(dim)(%cr)%C(reset)' 2>/dev/null
  echo

  if command -q eza
    eza --long --no-permissions --no-user --no-filesize --no-time \
      --git --icons=always --group-directories-first --color=always $dir
  else
    command ls -A -F $dir
  end

  set -l readme $dir/README* $dir/readme*
  test (count $readme) -gt 0; or return 0
  echo

  set -l style $HOME/.config/glow/styles/github-light.json
  if string match -q -i '*.md' -- $readme[1]; and command -q glow; and test -f $style
    set -l width $FZF_PREVIEW_COLUMNS
    test -n "$width"; or set width 80
    # glow waits on stdin whenever it is an open pipe, even with a file argument
    glow -s $style -w $width $readme[1] </dev/null | head -n 100
  else if command -q bat
    bat --style=plain --color=always --line-range=:100 $readme[1]
  else
    head -n 100 $readme[1]
  end
end

# Pulls one repo quietly and reports the outcome on a single line
function __ghq_update --argument-names dir label
  set -l before (git -C $dir rev-parse HEAD 2>/dev/null)
  set -l out (git -C $dir pull --ff-only --quiet 2>&1)
  if test $status -ne 0
    __ghq_report failed $label >&2
    string join \n -- "  "$out >&2
    return 1
  end

  set -l after (git -C $dir rev-parse HEAD 2>/dev/null)
  if test "$before" = "$after"
    __ghq_report current $label
  else
    set -l new (git -C $dir rev-list --count $before..$after 2>/dev/null)
    __ghq_report updated "$label ($new new commits)"
  end
end

function __ghq_get
  argparse u/update -- $argv; or return 1
  set -l root (__ghq_root)
  set -l failed 0

  if test (count $argv) -eq 0
    if not set -q _flag_update
      echo "usage: ghq get [-u] <repo>..." >&2
      return 1
    end
    set -l picked (__ghq_pick '' --multi --prompt='update> '); or return 1
    for repo in $picked
      __ghq_update $root/$repo $repo; or set failed 1
    end
    return $failed
  end

  for spec in $argv
    set -l parsed (__ghq_parse $spec)
    if test $status -ne 0
      set failed 1
      continue
    end
    set -l repo $parsed[1]
    set -l url $parsed[2]
    set -l kind $parsed[3]
    set -l host $parsed[4]
    set -l dir $root/$repo

    if test -e $dir
      # The path has no host in it, so a different origin here is a conflict
      set -l origin (__ghq_origin $dir)
      if test -n "$origin"; and test (string lower -- $origin) != (string lower -- $host/$repo)
        __ghq_report failed "$spec: $dir is already a checkout of $origin" >&2
        set failed 1
        continue
      end

      if set -q _flag_update
        __ghq_update $dir $repo; or set failed 1
      else
        __ghq_report exists $dir
      end
      continue
    end

    set -l parent (path dirname $dir)
    set -l parent_existed 0
    test -d $parent; and set parent_existed 1

    # gh honours `gh config git_protocol` and wires up `upstream` on forks
    if test "$kind" = shorthand; and test "$host" = github.com; and command -q gh
      gh repo clone $repo $dir
    else
      git clone $url $dir
    end

    if test $status -eq 0
      __ghq_report cloned $dir
    else
      set failed 1
      test $parent_existed -eq 0; and command rmdir $parent 2>/dev/null
      __ghq_report failed $spec >&2
    end
  end

  return $failed
end

function __ghq_list
  argparse p/full-path e/exact -- $argv; or return 1
  set -l repos (__ghq_repos)

  if test (count $argv) -gt 0
    set -l mode contains
    set -q _flag_exact; and set mode exact
    set repos (__ghq_filter $mode $argv[1] $repos)
  end

  test (count $repos) -gt 0; or return 0
  set -q _flag_full_path; and set repos (__ghq_root)/$repos
  isatty stdout; and set repos (__ghq_colorize $repos)
  printf '%s\n' $repos
end

# Prints the one repo a query refers to, opening the picker when the query is
# missing or ambiguous. Extra args go to fzf
function __ghq_resolve --argument-names query
  set -l fzf_args $argv[2..]
  if test -n "$query"
    set -l repos (__ghq_repos)
    set -l matches (__ghq_filter exact $query $repos)
    test (count $matches) -eq 1; or set matches (__ghq_filter contains $query $repos)
    if test (count $matches) -eq 1
      echo $matches
      return 0
    end
  end
  __ghq_pick "$query" $fzf_args
end

function __ghq_cd
  set -l repo (__ghq_resolve "$argv[1]" --prompt='cd> '); or return 1
  test -n "$repo"; or return 1
  cd (__ghq_root)/$repo
end

function __ghq_create
  if test (count $argv) -ne 1
    echo "usage: ghq create <repo>" >&2
    return 1
  end

  set -l parsed (__ghq_parse $argv[1]); or return 1
  set -l dir (__ghq_root)/$parsed[1]

  if test -e $dir; and test (count $dir/* $dir/.*) -gt 0
    echo "ghq: $dir already exists and is not empty" >&2
    return 1
  end

  command mkdir -p $dir; or return 1
  git init $dir; or return 1
  cd $dir
end

function __ghq_rm
  set -l root (__ghq_root)
  set -l query $argv[1]
  set -l repo

  # Only an exact match skips the picker, so a loose query can never choose
  # what gets deleted
  if test -n "$query"
    set -l matches (__ghq_filter exact $query (__ghq_repos))
    test (count $matches) -eq 1; and set repo $matches
  end
  if test -z "$repo"
    set repo (__ghq_pick "$query" --prompt='rm> '); or return 1
  end

  set -l dir $root/$repo
  if test -z "$repo"; or contains -- .. (string split / -- $repo); or not test -e $dir/.git
    echo "ghq: refusing to remove '$dir': not a repo under $root" >&2
    return 1
  end

  if test -f $dir/.git
    echo "ghq: $dir is a linked worktree; remove it with:" >&2
    echo "  git -C $dir worktree remove ." >&2
    return 1
  end

  set_color --bold; echo $dir; set_color normal

  set -l dirty (git -C $dir -c color.status=always status --short 2>/dev/null)
  if test (count $dirty) -gt 0
    set_color yellow; echo "uncommitted changes:"; set_color normal
    string join \n -- "  "$dirty
  end

  set -l unpushed (git -C $dir log --oneline --color=always --branches --not --remotes 2>/dev/null)
  if test (count $unpushed) -gt 0
    set_color yellow; echo "commits not on any remote:"; set_color normal
    string join \n -- "  "$unpushed
  end

  set -l stashes (git -C $dir stash list 2>/dev/null)
  if test (count $stashes) -gt 0
    set_color yellow; echo (count $stashes)" stash entries"; set_color normal
  end

  set -l worktrees (git -C $dir worktree list --porcelain 2>/dev/null | string match 'worktree *')
  if test (count $worktrees) -gt 1
    set_color yellow; echo "linked worktrees that will be orphaned:"; set_color normal
    string join \n -- "  "(string replace -- 'worktree ' '' $worktrees[2..])
  end

  read -l -P "Remove $dir? [y/N] " answer; or return 1
  if not string match -q -i -r '^y(es)?$' -- $answer
    echo "aborted"
    return 1
  end

  command rm -rf -- $dir; or return 1
  __ghq_report removed $dir

  # Drop owner and host directories this removal left empty
  set -l parent (path dirname $dir)
  while test "$parent" != "$root"; and command rmdir $parent 2>/dev/null
    set parent (path dirname $parent)
  end
  return 0
end
