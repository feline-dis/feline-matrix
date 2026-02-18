#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -eq 0 ]; then
    echo "Usage: bash scripts/create-account.sh -username <name> [-admin]"
    echo ""
    echo "Examples:"
    echo "  bash scripts/create-account.sh -username alice"
    echo "  bash scripts/create-account.sh -username admin -admin"
    exit 1
fi

fly ssh console -C "/usr/bin/create-account -config /etc/dendrite/dendrite.yaml $*"
