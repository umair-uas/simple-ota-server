#!/bin/bash
# Generate development CA and server certificates for RAUC Simple Server
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

# Backward compatibility: old usage was "generate-certs.sh [certs-dir] [server-ip]"
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

mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

echo "==> Generating CA certificate..."
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days $DAYS_VALID \
    -subj "/C=$COUNTRY/O=$ORG/CN=OTA Development CA" \
    -out ca.crt

echo "==> Generating server certificate"
echo "    DNS: $SERVER_NAME"
[[ -n "$SERVER_IP" ]] && echo "    IP : $SERVER_IP"

openssl genrsa -out server.key 2048
openssl req -new -key server.key \
    -subj "/C=$COUNTRY/O=$ORG/CN=$SERVER_NAME" \
    -out server.csr

# Create extensions file with SANs for stable DNS and optional IP
cat > server.ext <<EOF_SAN
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
    echo "IP.2 = $SERVER_IP" >> server.ext
fi

openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days $DAYS_VALID -sha256 -extfile server.ext

rm -f server.csr server.ext ca.srl

echo ""
echo "==> Certificates generated in $CERTS_DIR/"
echo "    ca.crt      - CA certificate (distribute to devices)"
echo "    ca.key      - CA private key (keep secure, used to sign device certs)"
echo "    server.crt  - Server certificate (SAN includes DNS: $SERVER_NAME${SERVER_IP:+, IP: $SERVER_IP})"
echo "    server.key  - Server private key"
echo ""
echo "Next: Generate device certificates with ./scripts/generate-device-cert.sh <device-id>"
