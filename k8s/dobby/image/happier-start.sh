#!/bin/bash
set -euo pipefail
echo 'Waiting for Happier pairing. Run happier auth login inside dobby over Tailscale SSH.'
until happier auth status --json 2>/dev/null | python3 -c '
import json,sys
try:
    status=json.load(sys.stdin)
    sys.exit(0 if status.get("ok") is True else 1)
except (ValueError, TypeError):
    sys.exit(1)
'; do
    sleep 15
done
exec happier daemon start-sync
