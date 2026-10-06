#!/usr/bin/env bash
#
# Starts the MyŠkoda Public API mock server.
#
# Usage:
#   mock/run.sh                              # HTTPS :8792 + HTTP :8793, scenario "default"
#   mock/run.sh --scenario rate-limit-exceeded
#   mock/run.sh --log-requests
#   mock/run.sh --scenario api-key-expired --log-requests --http-port 9000
#
# See mock/README.md for the full scenario list and how to switch scenarios
# at runtime without restarting.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$DIR/server.py" "$@"
