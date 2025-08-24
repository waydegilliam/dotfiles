function kpid --description "Kill process by PID"
    if count $argv > /dev/null
        set pid $argv[1]
        if kill $pid 2>/dev/null
            echo "Killed process $pid"
        else
            echo "Failed to kill process $pid"
        end
    else
        echo "Usage: kpid <pid>"
    end
end
