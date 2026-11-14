#!/bin/bash
set -euo pipefail
export FM_HOME=/workspace/firstmate
export FM_BACKEND=tmux
[[ -f "$FM_HOME/AGENTS.md" && -d "$FM_HOME/bin" ]] || {
    echo 'Firstmate checkout is missing or incomplete; inspect /workspace/firstmate.' >&2
    exit 1
}
cd "$FM_HOME"
command_name=${1:-claude}
[[ $# -eq 0 ]] || shift
case "$command_name" in
    setup)
        # Explicit one-time setup in the dedicated mounted home, never on bella's home.
        gh-axi setup hooks
        chrome-devtools-axi setup hooks
        ;;
    claude|codex)
        exec "$command_name" "$@"
        ;;
    *) echo 'Usage: dobby-firstmate [setup|claude|codex] [agent arguments...]' >&2; exit 2 ;;
esac
