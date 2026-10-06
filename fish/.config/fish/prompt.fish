function _dotfiles_prompt_git
    if command git branch --show-current 2>/dev/null | string shorten -m24 | read -l location
        command git rev-parse --git-dir --is-inside-git-dir | read -fL gdir in_gdir
        set location (set_color 008700)$location
    else if test $pipestatus[1] != 0
        return
    else if command git tag --points-at HEAD | string shorten -m24 | read location
        command git rev-parse --git-dir --is-inside-git-dir | read -fL gdir in_gdir
        set location '#' (set_color 008700)$location
        set location (string join '' -- $location)
    else
        command git rev-parse --git-dir --is-inside-git-dir --short HEAD | read -fL gdir in_gdir location
        set location @(set_color 008700)$location
    end

    if test -d $gdir/rebase-merge
        if not path is -v $gdir/rebase-merge/{msgnum,end}
            read -f step <$gdir/rebase-merge/msgnum
            read -f total_steps <$gdir/rebase-merge/end
        end
        test -f $gdir/rebase-merge/interactive && set -f operation rebase-i || set -f operation rebase-m
    else if test -d $gdir/rebase-apply
        if not path is -v $gdir/rebase-apply/{next,last}
            read -f step <$gdir/rebase-apply/next
            read -f total_steps <$gdir/rebase-apply/last
        end
        if test -f $gdir/rebase-apply/rebasing
            set -f operation rebase
        else if test -f $gdir/rebase-apply/applying
            set -f operation am
        else
            set -f operation am/rebase
        end
    else if test -f $gdir/MERGE_HEAD
        set -f operation merge
    else if test -f $gdir/CHERRY_PICK_HEAD
        set -f operation cherry-pick
    else if test -f $gdir/REVERT_HEAD
        set -f operation revert
    else if test -f $gdir/BISECT_LOG
        set -f operation bisect
    end

    test $in_gdir = true && set -l git_dir_args -C $gdir/..
    set -l stat (command git $git_dir_args --no-optional-locks status --porcelain 2>/dev/null)
    string match -qr '(0|(?<stash>.*))\n(0|(?<conflicted>.*))\n(0|(?<staged>.*))
(0|(?<dirty>.*))\n(0|(?<untracked>.*))(\n(0|(?<behind>.*))\t(0|(?<ahead>.*)))?' \
        "$(command git $git_dir_args stash list 2>/dev/null | count
        string match -r ^UU $stat | count
        string match -r ^[ADMR] $stat | count
        string match -r ^.[ADMR] $stat | count
        string match -r '^\?\?' $stat | count
        command git rev-list --count --left-right @{upstream}...HEAD 2>/dev/null)"

    set_color white
    echo -ns $location
    set_color FF0000
    echo -ns ' '$operation ' '$step/$total_steps
    set_color 5FD700
    echo -ns ' ⇣'$behind ' ⇡'$ahead
    set_color 008700
    echo -ns ' *'$stash
    set_color FF0000
    echo -ns ' ~'$conflicted
    set_color D7AF00
    echo -ns ' +'$staged ' !'$dirty
    set_color 008700
    echo -ns ' ?'$untracked
end

function _dotfiles_prompt_pwd -a available
    set -l anchors (set_color --bold 00AFFF)
    set -l truncated (set_color 8787AF)
    set -l dirs (set_color normal -b normal; set_color 0087AF)
    set -l markers .bzr .citc .git .hg .node-version .python-version .ruby-version \
        .shorten_folder_marker .svn .terraform bun.lockb Cargo.toml composer.json CVS \
        go.mod package.json build.zig
    set -l split_pwd (string replace -r '^'(string escape --style=regex -- "$HOME")'(?=/|$)' '~' -- "$PWD" | string split /)
    if test (count $split_pwd) -eq 1
        echo -ns $dirs$anchors'~'
        return
    end

    set -l output $split_pwd
    test -w . || set output[1] ' '$output[1]
    set output[-1] "$anchors$output[-1]$dirs"
    set -l width (string join / -- $output | string length --visible)
    set -l i 1
    for section in $split_pwd[2..-2]
        set -l parent (string join / -- $split_pwd[..$i] | string replace -r '^~(?=/|$)' "$HOME")
        set i (math $i+1)
        if path is $parent/$section/$markers
            set output[$i] "$anchors$section$dirs"
        else if test $width -gt $available
            string match -qr '(?<prefix>\..|.)' -- $section
            set -l siblings $parent/$prefix*/
            if set -l index (contains -i -- $parent/$section/ $siblings)
                set -e siblings[$index]
            end
            while string match -qr '^'(string escape --style=regex -- "$parent/$prefix") -- $siblings && string match -qr '(?<prefix>'(string escape --style=regex -- "$prefix")'.)' -- $section
            end
            if test -n "$prefix"
                set output[$i] "$truncated$prefix$dirs"
                set width (string join / -- $output | string length --visible)
            end
        end
    end
    echo -ns $dirs(string join / -- $output)
end

function _dotfiles_prompt_python
    if not test -n "$VIRTUAL_ENV"; and not path is .python-version Pipfile __init__.py pyproject.toml requirements.txt setup.py
        return
    end
    if command -q python3
        command python3 --version | string match -qr '(?<python_version>[\d.]+)'
    else if command -q python
        command python --version | string match -qr '(?<python_version>[\d.]+)'
    else
        return
    end
    set -q python_version || return
    set_color 00AFAF
    echo -ns '󰌠 '$python_version
    if test -n "$VIRTUAL_ENV"
        string match -qr '^.*/(?<dir>.*)/(?<base>.*)' -- $VIRTUAL_ENV
        if test "$dir" = virtualenvs
            string match -qr '(?<base>.*)-.*' -- $base
        else if contains -- "$base" virtualenv venv .venv env
            set base $dir
        end
        echo -ns ' ('$base')'
    end
end

function _dotfiles_prompt_right -a last_status duration job_count
    set -l pipeline $argv[4..]
    set -l items
    if string match -qv 0 $pipeline; and test "$pipeline" != 1
        set -l codes (fish_status_to_signal $pipeline | string replace SIG '' | string join '|')
        if test $last_status = 0
            set -a items (set_color 5FAF00)'✔ '$codes
        else
            set -a items (set_color D70000)'✘ '$codes
        end
    end

    if test $duration -gt 3000
        set -l hours (math -s0 "$duration/3600000")
        set -l minutes (math -s0 "$duration/60000%60")
        set -l seconds (math -s0 "$duration/1000%60")
        if test $hours != 0
            set -a items (set_color 87875F)"$hours"h" $minutes"m" $seconds"s
        else if test $minutes != 0
            set -a items (set_color 87875F)"$minutes"m" $seconds"s
        else
            set -a items (set_color 87875F)"$seconds"s
        end
    end

    if set -q SSH_TTY
        set -a items (set_color D7AF87)$USER'@'(string split -m1 . -- $hostname)[1]
    else if test "$EUID" = 0
        set -a items (set_color D7AF00)$USER'@'(string split -m1 . -- $hostname)[1]
    end
    if test $job_count -ge 1000
        set -a items (set_color 5FAF00)' '$job_count
    else if test $job_count -gt 0
        set -a items (set_color 5FAF00)''
    end
    set -l python_output "$(_dotfiles_prompt_python)"
    test -z "$python_output" || set -a items "$python_output"
    if set -q items[1]
        echo -ns ' '(string join (set_color 949494)' ' -- $items)
    end
end

function _dotfiles_prompt_worker -a result_dir generation parent_pid last_status duration job_count
    set -l git_output "$(_dotfiles_prompt_git)"
    set -l right_output "$(_dotfiles_prompt_right $last_status $duration $job_count $argv[7..])"
    test -d "$result_dir" || return
    printf '%s\0' $generation "$PWD" "$git_output" "$right_output" >"$result_dir/$generation.tmp"
    and command mv -f "$result_dir/$generation.tmp" "$result_dir/$generation"
    and command kill -s USR1 $parent_pid 2>/dev/null
end

function _dotfiles_prompt_cancel
    if set -q _dotfiles_prompt_worker_pid
        command kill $_dotfiles_prompt_worker_pid 2>/dev/null
        set -e _dotfiles_prompt_worker_pid
    end
    if set -q _dotfiles_prompt_result_dir
        command rm -f "$_dotfiles_prompt_result_dir/$_dotfiles_prompt_generation"{,.tmp}
    end
end

function _dotfiles_prompt_init -a prompt_file
    _dotfiles_prompt_cancel
    set -g _dotfiles_prompt_file $prompt_file
    if not set -q _dotfiles_prompt_result_dir
        set -g _dotfiles_prompt_result_dir (command mktemp -d -t dotfiles-prompt.XXXXXXXX)
    end
    set -g _dotfiles_prompt_generation 0
    set -g _dotfiles_prompt_directory ''
    set -g _dotfiles_prompt_git_output ''
    set -g _dotfiles_prompt_right_output ''
    set -g _dotfiles_prompt_last_status 0
    set -e _dotfiles_prompt_repaint

    function _dotfiles_prompt_receive --on-signal USR1
        set -l result_file "$_dotfiles_prompt_result_dir/$_dotfiles_prompt_generation"
        test -f "$result_file" || return
        set -l result (string split0 <"$result_file")
        command rm -f "$result_file"
        test (count $result) -eq 4 || return
        test "$result[1]" = "$_dotfiles_prompt_generation" || return
        test "$result[2]" = "$PWD" || return
        set -g _dotfiles_prompt_git_output "$result[3]"
        set -g _dotfiles_prompt_right_output "$result[4]"
        set -e _dotfiles_prompt_worker_pid
        set -g _dotfiles_prompt_repaint
        commandline -f repaint
    end

    function _dotfiles_prompt_resize --on-variable COLUMNS
        set -g _dotfiles_prompt_repaint
        commandline -f repaint
    end

    function _dotfiles_prompt_preexec --on-event fish_preexec
        _dotfiles_prompt_cancel
        set -g _dotfiles_prompt_generation (math $_dotfiles_prompt_generation+1)
        set -e _dotfiles_prompt_repaint
    end

    function _dotfiles_prompt_exit --on-event fish_exit
        _dotfiles_prompt_cancel
        command rm -rf "$_dotfiles_prompt_result_dir"
    end
end

function fish_prompt
    set -l last_status $status
    set -l last_pipeline $pipestatus
    if not set -e _dotfiles_prompt_repaint
        set -g _dotfiles_prompt_last_status $last_status
        _dotfiles_prompt_cancel
        set -g _dotfiles_prompt_generation (math $_dotfiles_prompt_generation+1)
        if test "$_dotfiles_prompt_directory" != "$PWD"
            set -g _dotfiles_prompt_git_output ''
            set -g _dotfiles_prompt_right_output ''
            set -g _dotfiles_prompt_directory "$PWD"
        end
        set -l job_count 0
        jobs -q && set job_count (jobs -p | count)
        set -l duration 0
        set -q CMD_DURATION && set duration $CMD_DURATION
        set -l fish_path (status fish-path)
        fish_term24bit=$fish_term24bit \
            $fish_path --no-config -c 'source $argv[1]; _dotfiles_prompt_worker $argv[2..]' \
            "$_dotfiles_prompt_file" "$_dotfiles_prompt_result_dir" $_dotfiles_prompt_generation $fish_pid \
            $last_status $duration $job_count $last_pipeline &
        set -g _dotfiles_prompt_worker_pid $last_pid
        builtin disown
    end

    set -l git_output "$_dotfiles_prompt_git_output"
    test -z "$git_output" || set git_output (set_color 949494)' '$git_output
    set -l character (set_color 008700)' ❯'
    test $_dotfiles_prompt_last_status = 0 || set character (set_color FF0000)' ❯'
    set -l available (math $COLUMNS - (string length --visible -- "$git_output$character$_dotfiles_prompt_right_output") - 34)
    echo -ns (_dotfiles_prompt_pwd $available) "$git_output$character" (set_color normal)' '
end

function fish_right_prompt
    echo -ns "$_dotfiles_prompt_right_output" (set_color normal)
end

function fish_mode_prompt
end

if status is-interactive
    _dotfiles_prompt_init (status filename)
end
