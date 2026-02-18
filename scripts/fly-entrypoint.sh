#!/bin/sh
set -eu

config="/etc/dendrite/dendrite.yaml"

# Inject DATABASE_URI into the config at runtime.
# Dendrite does not support env var substitution in YAML.
if [ -n "${DATABASE_URI:-}" ]; then
    escaped_uri=$(printf '%s' "$DATABASE_URI" | sed 's/[&]/\\&/g')
    sed -i "s|connection_string:.*|connection_string: ${escaped_uri}|" "$config"
fi

# Inject registration shared secret
if [ -n "${REGISTRATION_SHARED_SECRET:-}" ]; then
    sed -i "s|REGISTRATION_SHARED_SECRET_PLACEHOLDER|${REGISTRATION_SHARED_SECRET}|" "$config"
fi

# Remap data paths to the Fly volume mount
sed -i 's|/var/dendrite/jetstream|/data/jetstream|' "$config"
sed -i 's|/var/dendrite/media|/data/media|' "$config"
sed -i 's|/var/dendrite/searchindex|/data/searchindex|' "$config"

mkdir -p /data/media /data/jetstream /data/searchindex

# Generate signing key on the persistent volume if it doesn't exist
if [ ! -f /data/matrix_key.pem ]; then
    /usr/bin/generate-keys -private-key /data/matrix_key.pem
fi
sed -i 's|private_key:.*|private_key: /data/matrix_key.pem|' "$config"

# Start Dendrite in the background on port 8009 (client API).
# The registration proxy listens on 8008 and forwards to 8009.
# Federation stays on 8448 (handled directly by fly.toml TCP service).
/usr/bin/dendrite --config "$config" \
    --http-bind-address :8009 \
    --https-bind-address :8448 &

# Start the registration proxy in the foreground
exec /usr/local/bin/registration-proxy
