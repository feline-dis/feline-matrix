#!/bin/sh
set -eu

config="/etc/conduwuit/conduwuit.toml"
runtime_config="/tmp/conduwuit.toml"
cp "$config" "$runtime_config"

# Inject registration token (invite code)
if [ -n "${INVITE_CODE:-}" ]; then
    sed -i "s|REGISTRATION_TOKEN_PLACEHOLDER|${INVITE_CODE}|" "$runtime_config"
fi

exec /usr/local/bin/conduwuit --config "$runtime_config"
