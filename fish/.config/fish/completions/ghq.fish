set -l commands get list cd rm create root help

complete -c ghq -f

complete -c ghq -n "not __fish_seen_subcommand_from $commands" -a get -d "Clone a repo into the root"
complete -c ghq -n "not __fish_seen_subcommand_from $commands" -a list -d "List repos"
complete -c ghq -n "not __fish_seen_subcommand_from $commands" -a cd -d "Jump to a repo"
complete -c ghq -n "not __fish_seen_subcommand_from $commands" -a rm -d "Delete a repo"
complete -c ghq -n "not __fish_seen_subcommand_from $commands" -a create -d "Create and git init a new repo"
complete -c ghq -n "not __fish_seen_subcommand_from $commands" -a root -d "Print the root directory"
complete -c ghq -n "not __fish_seen_subcommand_from $commands" -a help -d "Show usage"

complete -c ghq -n "__fish_seen_subcommand_from get" -s u -l update -d "Pull repos that already exist"
complete -c ghq -n "__fish_seen_subcommand_from list" -s p -l full-path -d "Print full paths"
complete -c ghq -n "__fish_seen_subcommand_from list" -s e -l exact -d "Match the query exactly"

complete -c ghq -n "__fish_seen_subcommand_from list cd rm" -a "(ghq list)"
