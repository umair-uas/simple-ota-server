#!/bin/bash
# Generate CA (if missing) and server certificates for RAUC Simple Server
# This is a convenience wrapper around generate-ca.sh and generate-server-cert.sh
#
# Usage: generate-certs.sh [certs-dir] [server-dns-name] [server-ip]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/generate-ca.sh" "${1:-certs}"
"$SCRIPT_DIR/generate-server-cert.sh" "$@"
