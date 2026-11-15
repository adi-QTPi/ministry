#!/bin/bash
set -euo pipefail
umask 077
mkdir -p "$HOME/.happier" "$HOME/.config" "$HOME/.cache" "$HOME/.local/bin"
mkdir -p "$HOME/.config/dobby/previews"
dobby-seed-firstmate /opt/firstmate /workspace/firstmate
dobby-pangolin seed

# Optional centrally managed token file. Read literal values, never source shell.
credentials_file="$HOME/.config/dobby/credentials.env"
if [[ -f "$credentials_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        key=${line%%=*}
        value=${line#*=}
        case "$key" in
            COMMAND_CODE_API_KEY|GH_TOKEN)
                [[ "$line" == *=* && -n "$value" ]] || { echo "Invalid credential entry: $key" >&2; exit 1; }
                export "$key=$value"
                ;;
            *) echo "Unsupported credential key: $key" >&2; exit 1 ;;
        esac
    done < "$credentials_file"
fi

# Happier and Herdr inherit the same mounted credentials.
# Native Tailscale SSH provides interactive shell access.
exec /usr/bin/supervisord -n -c /etc/dobby-supervisord.conf
