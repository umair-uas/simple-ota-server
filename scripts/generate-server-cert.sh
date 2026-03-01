#!/bin/bash
# Generate a server certificate signed by the CA
# Usage: generate-server-cert.sh [certs-dir] [server-dns-name] [server-ip]
set -euo pipefail

CERTS_DIR="${1:-certs}"
SERVER_NAME="${2:-ota-gw.local}"
SERVER_IP="${3:-}"
DAYS_VALID=3650
COUNTRY="DE"
ORG="RAUC Simple Server"

is_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

# Backward compatibility: old usage was "script [certs-dir] [server-ip]"
if is_ipv4 "$SERVER_NAME" && [[ -z "$SERVER_IP" ]]; then
    SERVER_IP="$SERVER_NAME"
    SERVER_NAME="ota-gw.local"
fi

# Auto-detect IP if not explicitly provided
if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

if [[ -z "$SERVER_NAME" ]]; then
    echo "Error: server DNS name is required"
    echo "Usage: $0 [certs-dir] [server-dns-name] [server-ip]"
    exit 1
fi

# Pre-checks: CA must exist
if [[ ! -f "$CERTS_DIR/ca.crt" ]] || [[ ! -f "$CERTS_DIR/ca.key" ]]; then
    echo "Error: CA certificate not found in $CERTS_DIR/"
    echo "Run ./scripts/generate-ca.sh first"
    exit 1
fi

# Pre-check: ca.key must not be world-readable
CA_KEY_PERMS=$(stat -c '%a' "$CERTS_DIR/ca.key" 2>/dev/null || stat -f '%Lp' "$CERTS_DIR/ca.key" 2>/dev/null)
if [[ "${CA_KEY_PERMS: -1}" != "0" ]]; then
    echo "Error: $CERTS_DIR/ca.key is world-readable (permissions: $CA_KEY_PERMS)"
    echo "Fix with: chmod 0600 $CERTS_DIR/ca.key"
    exit 1
fi

echo "==> Generating server certificate"
echo "    DNS: $SERVER_NAME"
[[ -n "$SERVER_IP" ]] && echo "    IP : $SERVER_IP"

openssl genrsa -out "$CERTS_DIR/server.key" 2048
openssl req -new -key "$CERTS_DIR/server.key" \
    -subj "/C=$COUNTRY/O=$ORG/CN=$SERVER_NAME" \
    -out "$CERTS_DIR/server.csr"

# Create extensions file with SANs for stable DNS and optional IP
cat > "$CERTS_DIR/server.ext" <<EOF_SAN
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = ota-server
DNS.3 = $SERVER_NAME
IP.1 = 127.0.0.1
EOF_SAN

if [[ -n "$SERVER_IP" ]]; then
    echo "IP.2 = $SERVER_IP" >> "$CERTS_DIR/server.ext"
fi

openssl x509 -req -in "$CERTS_DIR/server.csr" -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" -CAcreateserial \
    -out "$CERTS_DIR/server.crt" -days $DAYS_VALID -sha256 -extfile "$CERTS_DIR/server.ext"

rm -f "$CERTS_DIR/server.csr" "$CERTS_DIR/server.ext" "$CERTS_DIR/ca.srl"

echo ""
echo "==> Server certificate generated in $CERTS_DIR/"
echo "    server.crt  - Server certificate (SAN includes DNS: $SERVER_NAME${SERVER_IP:+, IP: $SERVER_IP})"
echo "    server.key  - Server private key"
