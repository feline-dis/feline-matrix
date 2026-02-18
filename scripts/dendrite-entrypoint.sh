#!/bin/sh
set -eu

config="/etc/dendrite/dendrite.yaml"
runtime_config="/tmp/dendrite.yaml"
cp "$config" "$runtime_config"

# Inject DATABASE_URI
if [ -n "${DATABASE_URI:-}" ]; then
    escaped=$(printf '%s' "$DATABASE_URI" | sed 's/[&]/\\&/g')
    sed -i "s|connection_string:.*|connection_string: ${escaped}|" "$runtime_config"
fi

# Inject registration shared secret
if [ -n "${REGISTRATION_SHARED_SECRET:-}" ]; then
    sed -i "s|REGISTRATION_SHARED_SECRET_PLACEHOLDER|${REGISTRATION_SHARED_SECRET}|" "$runtime_config"
fi

# Generate signing key on first boot
if [ ! -f /data/matrix_key.pem ]; then
    /usr/bin/generate-keys -private-key /data/matrix_key.pem
fi

mkdir -p /data/media /data/jetstream /data/searchindex

exec /usr/bin/dendrite --config "$runtime_config" --http-bind-address :8008
