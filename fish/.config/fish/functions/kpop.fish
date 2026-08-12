function kpop --description "Kill process on port"
    set -l ports

    if test (count $argv) -gt 0
        set ports $argv
    else if not isatty stdin
        read ports
    end

    if test (count $ports) -eq 0
        echo "Usage: kpop <port>"
        return 1
    end

    for port in $ports
        lsof -t -i :$port | xargs kill
    end
end
