# On a machine reached through VS Code Remote-SSH, make `code` open files in the
# connected VS Code window. Never shadows a real `code` install on a host machine
if not command -q code; and test -d ~/.vscode-server
    function code --description 'Open files in the VS Code window connected over Remote-SSH'
        set -l bins ~/.vscode-server/cli/servers/*/server/bin/remote-cli/code
        set -l socks /tmp/vscode-ipc-*.sock /run/user/(id -u)/vscode-ipc-*.sock
        if test (count $bins) -eq 0 -o (count $socks) -eq 0
            echo "code: no VS Code Remote-SSH session found — connect from your Mac first" >&2
            return 1
        end
        set -l bin (ls -t $bins | head -1)
        set -l sock (ls -t $socks | head -1)
        VSCODE_IPC_HOOK_CLI=$sock $bin $argv
    end
end
