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

# A different key makes Bridge overwrite vault.enc with an empty vault, so pin
# the key's hash next to the vault and refuse to start if it changes.
CONFIG_DIR="$HOME/.config/protonmail/bridge-v3"
mkdir -p "$CONFIG_DIR"
KEY_HASH="$(printf '%s' "$BRIDGE_VAULT_KEY" | base64 -d | sha256sum | cut -d' ' -f1)"
if [ -e "$CONFIG_DIR/vault-key.sha256" ]; then
    [ "$(cat "$CONFIG_DIR/vault-key.sha256")" = "$KEY_HASH" ] \
        || { echo "BRIDGE_VAULT_KEY differs from the key that created this vault" >&2; exit 1; }
elif [ ! -e "$CONFIG_DIR/vault.enc" ]; then
    printf '%s' "$KEY_HASH" > "$CONFIG_DIR/vault-key.sha256"
else
    echo "vault.enc exists without vault-key.sha256; refusing to guess the key" >&2
    exit 1
fi

# /run/bridge survives container restarts inside a pod; start clean.
rm -rf "$GNUPGHOME" "$PASSWORD_STORE_DIR"
mkdir -p "$GNUPGHOME" "$PASSWORD_STORE_DIR"
chmod 700 "$GNUPGHOME"

gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key bridge-keychain default default never
pass init bridge-keychain >/dev/null

printf '{"ServerURL":"protonmail/bridge-v3/users/bridge-vault-key","Username":"bridge-vault-key","Secret":"%s"}' \
    "$BRIDGE_VAULT_KEY" | docker-credential-pass store

STORED="$(printf '%s' 'protonmail/bridge-v3/users/bridge-vault-key' | docker-credential-pass get | sed -n 's/.*"Secret":"\([^"]*\)".*/\1/p')"
[ "$STORED" = "$BRIDGE_VAULT_KEY" ] || { echo "vault key read-back from pass failed" >&2; exit 1; }
unset BRIDGE_VAULT_KEY
exec bridge "$@"
