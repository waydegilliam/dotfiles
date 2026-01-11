function gcm --description "Git commit with optional AI message generation"
    argparse 'g/generate' -- $argv
    or return 1

    if set -q _flag_generate
        if git diff --cached --quiet
            echo "No staged changes to commit"
            return 1
        end

        set -l generated_msg (git --no-pager diff --cached | claude --model haiku --print --no-tools "Generate a conventional commit message for this diff. Output only the commit message, nothing else.")
        or return 1

        echo "Generated commit message:"
        echo "─────────────────────────"
        echo $generated_msg
        echo "─────────────────────────"
        read -l -P "[a]ccept, [e]dit, [c]ancel? " action

        switch $action
            case a A
                git commit -m "$generated_msg"
            case e E
                git commit -e -m "$generated_msg"
            case '*'
                echo "Cancelled"
                return 1
        end
    else if test (count $argv) -gt 0
        git commit -m "$argv"
    else
        git commit
    end
end
