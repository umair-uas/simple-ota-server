#!/bin/bash
# Generate a device client certificate signed by the CA
set -e

DEVICE_ID="${1:?Usage: $0 <device-id>}"
CERTS_DIR="${2:-certs}"
DAYS_VALID=3650
COUNTRY="DE"
ORG="RAUC Simple Server"

if [[ ! -f "$CERTS_DIR/ca.key" ]] || [[ ! -f "$CERTS_DIR/ca.crt" ]]; then
    echo "Error: CA certificates not found in $CERTS_DIR/"
    echo "Run ./scripts/generate-certs.sh first"
    exit 1
fi

DEVICES_DIR="$CERTS_DIR/devices"
mkdir -p "$DEVICES_DIR"

echo "==> Generating certificate for device: $DEVICE_ID"

openssl genrsa -out "$DEVICES_DIR/$DEVICE_ID.key" 2048
openssl req -new -key "$DEVICES_DIR/$DEVICE_ID.key" \
    -subj "/C=$COUNTRY/O=$ORG/CN=$DEVICE_ID" \
    -out "$DEVICES_DIR/$DEVICE_ID.csr"

openssl x509 -req -in "$DEVICES_DIR/$DEVICE_ID.csr" \
    -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" -CAcreateserial \
    -out "$DEVICES_DIR/$DEVICE_ID.crt" -days $DAYS_VALID -sha256

rm -f "$DEVICES_DIR/$DEVICE_ID.csr" "$CERTS_DIR/ca.srl"

echo ""
echo "==> Device certificate generated:"
echo "    $DEVICES_DIR/$DEVICE_ID.crt"
echo "    $DEVICES_DIR/$DEVICE_ID.key"
echo ""
echo "Copy these files to the device along with ca.crt"
echo ""
echo "Test with:"
echo "  curl --cert $DEVICES_DIR/$DEVICE_ID.crt \\"
echo "       --key $DEVICES_DIR/$DEVICE_ID.key \\"
echo "       --cacert $CERTS_DIR/ca.crt \\"
echo "       https://localhost:8443/api/v1/manifest.json"
