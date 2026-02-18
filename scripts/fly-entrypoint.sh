#!/bin/sh
set -eu

config="/etc/dendrite/dendrite.yaml"

# Inject DATABASE_URI into the config at runtime.
# Dendrite does not support env var substitution in YAML.
if [ -n "${DATABASE_URI:-}" ]; then
    escaped_uri=$(printf '%s' "$DATABASE_URI" | sed 's/[&]/\\&/g')
    sed -i "s|connection_string:.*|connection_string: ${escaped_uri}|" "$config"
fi

# Remap data paths to the Fly volume mount
sed -i 's|/var/dendrite/jetstream|/data/jetstream|' "$config"
sed -i 's|/var/dendrite/media|/data/media|' "$config"
sed -i 's|/var/dendrite/searchindex|/data/searchindex|' "$config"

mkdir -p /data/media /data/jetstream /data/searchindex

exec /usr/bin/dendrite --config "$config"
