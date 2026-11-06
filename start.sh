#!/bin/sh
# Puts the Bridge vault key from $BRIDGE_VAULT_KEY into a throwaway pass store,
# then runs Bridge. Without a key Bridge would fall back to an unencrypted
# vault, so refuse to start instead.
set -eu

: "${BRIDGE_VAULT_KEY:?BRIDGE_VAULT_KEY is not set}"

export GNUPGHOME="${GNUPGHOME:-/run/bridge/gnupg}"
export PASSWORD_STORE_DIR="${PASSWORD_STORE_DIR:-/run/bridge/pass}"
printf '%s' "$BRIDGE_VAULT_KEY" | base64 -d >/dev/null 2>&1 \
    || { echo "BRIDGE_VAULT_KEY must be base64" >&2; exit 1; }

# /run/bridge survives container restarts inside a pod; start clean.
rm -rf "$GNUPGHOME" "$PASSWORD_STORE_DIR"
mkdir -p "$GNUPGHOME" "$PASSWORD_STORE_DIR"
chmod 700 "$GNUPGHOME"

gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key bridge-keychain default default never
pass init bridge-keychain >/dev/null

printf '{"ServerURL":"protonmail/bridge-v3/users/bridge-vault-key","Username":"bridge-vault-key","Secret":"%s"}' \
    "$BRIDGE_VAULT_KEY" | docker-credential-pass store


unset BRIDGE_VAULT_KEY
exec bridge "$@"
