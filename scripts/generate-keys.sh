#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f config/matrix_key.pem ]; then
    echo "config/matrix_key.pem already exists, skipping generation."
    exit 0
fi

mkdir -p config

docker run --rm \
    --entrypoint="/usr/bin/generate-keys" \
    -v "$(pwd)/config:/mnt" \
    ghcr.io/element-hq/dendrite-monolith:latest \
    -private-key /mnt/matrix_key.pem

echo "Generated config/matrix_key.pem"
