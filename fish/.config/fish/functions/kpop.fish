function kpop --description "Kill process on port"
    set -l port

    if test (count $argv) -gt 0
        set port $argv[1]
    else if not isatty stdin
        read port
    end

    if test -z "$port"
        echo "Usage: kpop <port>"
        return 1
    end

    lsof -t -i :$port | xargs kill
end
