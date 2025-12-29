function __check_venv --on-variable PWD --description 'Source venv (if exists) on directory change'
  status --is-command-substitution; and return
  if test -d venv
    source ./venv/bin/activate.fish
  else if test -d .venv
    source ./.venv/bin/activate.fish
  end
end
