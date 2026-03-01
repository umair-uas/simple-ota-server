#!/bin/bash
# Verify certificate chain integrity
# Usage: verify-chain.sh [certs-dir]
set -euo pipefail

CERTS_DIR="${1:-certs}"
FAIL=0

verify_cert() {
    local label="$1"
    local cert="$2"
    local ca="$3"

    if [[ ! -f "$cert" ]]; then
        echo "SKIP  $label ($cert not found)"
        return
    fi

    if openssl verify -CAfile "$ca" "$cert" >/dev/null 2>&1; then
        echo "PASS  $label"
    else
        echo "FAIL  $label"
        FAIL=1
    fi
}

if [[ ! -f "$CERTS_DIR/ca.crt" ]]; then
    echo "Error: CA certificate not found at $CERTS_DIR/ca.crt"
    exit 1
fi

# Verify CA is self-signed
if openssl verify -CAfile "$CERTS_DIR/ca.crt" "$CERTS_DIR/ca.crt" >/dev/null 2>&1; then
    echo "PASS  ca.crt (self-signed)"
else
    echo "FAIL  ca.crt (self-signed verification failed)"
    FAIL=1
fi

# Verify server cert
verify_cert "server.crt" "$CERTS_DIR/server.crt" "$CERTS_DIR/ca.crt"

# Verify all device certs
if [[ -d "$CERTS_DIR/devices" ]]; then
    for cert in "$CERTS_DIR/devices/"*.crt; do
        [[ -f "$cert" ]] || continue
        name=$(basename "$cert")
        verify_cert "devices/$name" "$cert" "$CERTS_DIR/ca.crt"
    done
fi

exit $FAIL
