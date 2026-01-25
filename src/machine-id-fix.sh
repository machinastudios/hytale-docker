#!/usr/bin/env bash

# Target file
TARGET="/etc/machine-id"

# If the file already exists and is not empty, use it
if [ -s "$TARGET" ] && [ -n "$(cat "$TARGET")" ]; then
    exit 0
fi

UUID=""

# Attempt deterministic derivation
HOSTNAME_VAL="$(hostname 2>/dev/null)"
MAC_VAL="$(cat /sys/class/net/eth0/address 2>/dev/null)"
IMAGE_FINGERPRINT="$(sha256sum /etc/os-release 2>/dev/null | awk '{print $1}')"

# Build deterministic seed if we got anything useful
SEED=""
if [ -n "$HOSTNAME_VAL" ] || [ -n "$MAC_VAL" ] || [ -n "$IMAGE_FINGERPRINT" ]; then
    SEED="$(printf "%s-%s-%s" "$HOSTNAME_VAL" "$MAC_VAL" "$IMAGE_FINGERPRINT")"
fi

# If seed exists, derive UUID from it
if [ -n "$SEED" ]; then
    SHA="$(printf "%s" "$SEED" | sha1sum | awk '{print $1}')"
    UUID="${SHA:0:8}${SHA:8:4}${SHA:12:4}${SHA:16:4}${SHA:20:12}"
fi

# Random fallback if deterministic failed
if [ -z "$UUID" ]; then
    if command -v uuidgen >/dev/null 2>&1; then
        UUID=$(uuidgen | tr -d '-')
    elif [ -r /proc/sys/kernel/random/uuid ]; then
        UUID=$(tr -d '-' < /proc/sys/kernel/random/uuid)
    else
        UUID=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi
fi

# Final validation
if [ -z "$UUID" ]; then
    echo "Failed to generate UUID"
    exit 1
fi

# Write the UUID to the target file
echo "$UUID" > "$TARGET"