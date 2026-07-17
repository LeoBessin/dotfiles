#!/bin/sh
# Get-or-create the TOTP vault's symmetric encryption passphrase in the OS keyring.
# Prints the passphrase to stdout.
set -e

key=$(secret-tool lookup service quickshell-totp account vault-key 2>/dev/null || true)

if [ -z "$key" ]; then
    key=$(openssl rand -base64 32)
    printf '%s' "$key" | secret-tool store --label="QuickShell TOTP Vault Key" service quickshell-totp account vault-key
fi

printf '%s' "$key"
