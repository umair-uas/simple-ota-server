#!/bin/bash
# Generate development CA and server certificates for RAUC Simple Server
set -e

CERTS_DIR="${1:-certs}"
SERVER_IP="${2:-}"
DAYS_VALID=3650
COUNTRY="DE"
ORG="RAUC Simple Server"

mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# Prompt for server IP if not provided
if [[ -z "$SERVER_IP" ]]; then
    # Try to detect default IP
    DEFAULT_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    read -p "Server IP address [$DEFAULT_IP]: " SERVER_IP
    SERVER_IP="${SERVER_IP:-$DEFAULT_IP}"
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "Error: Server IP address is required"
    echo "Usage: $0 [certs-dir] [server-ip]"
    exit 1
fi

echo "==> Generating CA certificate..."
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days $DAYS_VALID \
    -subj "/C=$COUNTRY/O=$ORG/CN=OTA Development CA" \
    -out ca.crt

echo "==> Generating server certificate for IP: $SERVER_IP"
openssl genrsa -out server.key 2048
openssl req -new -key server.key \
    -subj "/C=$COUNTRY/O=$ORG/CN=ota-server" \
    -out server.csr

# Create extensions file with SAN including the server IP
cat > server.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = ota-server
IP.1 = 127.0.0.1
IP.2 = $SERVER_IP
EOF

openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days $DAYS_VALID -sha256 -extfile server.ext

rm -f server.csr server.ext ca.srl

echo ""
echo "==> Certificates generated in $CERTS_DIR/"
echo "    ca.crt      - CA certificate (distribute to devices)"
echo "    ca.key      - CA private key (keep secure, used to sign device certs)"
echo "    server.crt  - Server certificate (valid for: localhost, $SERVER_IP)"
echo "    server.key  - Server private key"
echo ""
echo "Next: Generate device certificates with ./scripts/generate-device-cert.sh <device-id>"
