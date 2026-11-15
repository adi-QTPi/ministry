#!/bin/bash
set -euo pipefail
cd /opt/pangolin
export ENVIRONMENT=prod
exec node dist/cli.mjs "$@"
