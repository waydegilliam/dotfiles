function qq --description "Quick question via codex (fast mode, low thinking)"
  if test (count $argv) -eq 0
    echo "usage: qq <question>" >&2
    return 1
  end
  set -l err (mktemp)
  codex exec \
    --skip-git-repo-check \
    --ephemeral \
    --disable hooks \
    -s read-only \
    -m gpt-5.5 \
    -c 'service_tier="fast"' \
    -c 'model_reasoning_effort="low"' \
    -c 'tools.web_search=true' \
    "$argv" 2>$err | glow -s $HOME/.config/glow/styles/github-light.json -
  set -l exit_code $pipestatus[1]
  if test $exit_code -ne 0
    cat $err >&2
  end
  rm -f $err
  return $exit_code
end
