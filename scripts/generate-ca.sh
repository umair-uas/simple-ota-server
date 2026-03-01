#!/bin/bash
# Generate or import a CA certificate for RAUC Simple Server
# Usage: generate-ca.sh [certs-dir] [--force] [--import <path>]
set -euo pipefail

CERTS_DIR=""
FORCE=false
IMPORT_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=true
            shift
            ;;
        --import)
            IMPORT_PATH="${2:?--import requires a path argument}"
            shift 2
            ;;
        *)
            if [[ -z "$CERTS_DIR" ]]; then
                CERTS_DIR="$1"
            else
                echo "Error: unexpected argument '$1'"
                echo "Usage: $0 [certs-dir] [--force] [--import <path>]"
                exit 1
            fi
            shift
            ;;
    esac
done

CERTS_DIR="${CERTS_DIR:-certs}"
DAYS_VALID=3650
COUNTRY="DE"
ORG="RAUC Simple Server"

mkdir -p "$CERTS_DIR"

# Import mode
if [[ -n "$IMPORT_PATH" ]]; then
    if [[ ! -f "$IMPORT_PATH/ca.crt" ]] || [[ ! -f "$IMPORT_PATH/ca.key" ]]; then
        echo "Error: $IMPORT_PATH must contain both ca.crt and ca.key"
        exit 1
    fi
    if [[ -f "$CERTS_DIR/ca.crt" ]] && ! $FORCE; then
        echo "CA already exists in $CERTS_DIR/. Use --force to overwrite."
        exit 0
    fi
    cp "$IMPORT_PATH/ca.crt" "$CERTS_DIR/ca.crt"
    cp "$IMPORT_PATH/ca.key" "$CERTS_DIR/ca.key"
    chmod 0600 "$CERTS_DIR/ca.key"
    echo "==> CA imported from $IMPORT_PATH"
    exit 0
fi

# Check if CA already exists
if [[ -f "$CERTS_DIR/ca.crt" ]] && [[ -f "$CERTS_DIR/ca.key" ]] && ! $FORCE; then
    echo "CA already exists in $CERTS_DIR/. Use --force to regenerate."
    echo "WARNING: Regenerating the CA will invalidate all existing device certificates."
    exit 0
fi

echo "==> Generating CA certificate..."
openssl genrsa -out "$CERTS_DIR/ca.key" 4096
openssl req -x509 -new -nodes -key "$CERTS_DIR/ca.key" -sha256 -days $DAYS_VALID \
    -subj "/C=$COUNTRY/O=$ORG/CN=OTA Development CA" \
    -out "$CERTS_DIR/ca.crt"
chmod 0600 "$CERTS_DIR/ca.key"

echo "==> CA certificate generated in $CERTS_DIR/"
echo "    ca.crt  - CA certificate (distribute to devices)"
echo "    ca.key  - CA private key (keep secure, used to sign certs)"
