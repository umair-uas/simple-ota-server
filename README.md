# RAUC Simple Server

A lightweight OTA update server for [RAUC](https://rauc.io) with mTLS device authentication, HTTP/2 streaming, and a web dashboard.

## Features

- **Web Dashboard** — Upload bundles, activate releases, drag-and-drop support
- **mTLS Authentication** — Secure device-to-server communication with client certificates
- **HTTP/2 Streaming** — Fast bundle downloads via RAUC's nbd streaming client
- **REST API** — Simple JSON manifest for device polling
- **Docker Deployment** — Single `docker compose up` to run
- **DNS-based Certs** — Stable TLS certificates that survive IP changes

## Quick Start

```bash
# Clone the repo
git clone https://github.com/umair-uas/simple-ota-server.git
cd simple-ota-server

# Configure
cp .env.example .env
vim .env  # Set SERVER_URL and COMPATIBLE

# Generate certificates (DNS name + optional IP)
./scripts/generate-certs.sh certs ota-gw.local 192.168.0.193

# Start
docker compose up -d
```

**Dashboard** (localhost only — use SSH tunnel for remote access):

```bash
# From remote machine
ssh -L 8080:127.0.0.1:8080 user@server-host
open http://localhost:8080
```

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              NGINX                      │
                    │  ┌───────────────┐  ┌───────────────┐   │
  Devices ─────────►│  │  :8443 mTLS   │  │  :8080 HTTP   │◄──┼──── Admin
  (with certs)      │  │  HTTP/2       │  │   Dashboard   │   │  (SSH tunnel)
                    │  └───────┬───────┘  └───────┬───────┘   │
                    └──────────┼──────────────────┼───────────┘
                               │                  │
                               ▼                  ▼
                    ┌─────────────────────────────────────────┐
                    │           FastAPI (:8081)               │
                    └─────────────────────────────────────────┘
```

## Configuration

Edit `.env`:

```bash
# URL devices use to download bundles (must be reachable from devices)
SERVER_URL=https://ota-gw.local:8443

# RAUC compatible string (must match device's /etc/rauc/system.conf)
COMPATIBLE=my-device-type
```

## Certificates

The CA is generated once and reused for all server and device certificates. Regenerating the CA invalidates every device certificate signed by it.

### Quick setup (wrapper script)

```bash
# Creates CA (if missing) + server cert in one command
./scripts/generate-certs.sh certs ota-gw.local 192.168.0.193
```

### Individual scripts

**Generate CA** — run once, or when setting up a new deployment:

```bash
./scripts/generate-ca.sh certs              # generate new CA (no-op if exists)
./scripts/generate-ca.sh certs --force       # regenerate (invalidates all device certs!)
./scripts/generate-ca.sh certs --import /path/to/existing-ca  # import external CA
```

**Generate server certificate** — requires an existing CA:

```bash
./scripts/generate-server-cert.sh certs ota-gw.local 192.168.0.193
# IP is auto-detected if omitted
```

**Generate device certificate** — requires an existing CA:

```bash
./scripts/generate-device-cert.sh <device-id>
# Creates: certs/devices/<device-id>.crt, <device-id>.key
```

**Verify certificate chain** — checks CA, server, and all device certs:

```bash
./scripts/verify-chain.sh certs
# PASS  ca.crt (self-signed)
# PASS  server.crt
# PASS  devices/my-device.crt
```

### DNS Resolution

The `mdns` sidecar container advertises `ota-gw.local` via Avahi/mDNS. This is best-effort — multicast DNS does not cross most consumer routers, and the sidecar requires host Avahi, D-Bus access, and an AppArmor exception (Linux-only).

Fallback options if mDNS isn't available on your network:

- **Direct IP URL** — Set `SERVER_URL=https://<ip>:8443` in `.env` and include the IP in the cert SAN (the default scripts already do this)
- **Router DNS** — Add a local DNS entry on your router pointing `ota-gw.local` to the server IP

## Device Integration

### RAUC system.conf (streaming with mTLS)

Configure RAUC on your device to use streaming with client certificates:

```ini
[streaming]
tls-cert=/etc/ota/device.crt
tls-key=/etc/ota/device.key
tls-ca=/etc/ota/ca.crt
send-headers=boot-id;machine-id;transaction-id
```

Copy `ca.crt`, `device.crt`, and `device.key` to the device's `/etc/ota/` directory.

### Checking for updates

Devices poll the manifest endpoint:

```bash
curl --cert device.crt --key device.key --cacert ca.crt \
  https://ota-gw.local:8443/api/v1/manifest.json
```

Response:
```json
{
  "bundle_url": "https://ota-gw.local:8443/bundles/update-1.2.0.raucb",
  "compatible": "my-device-type",
  "filename": "update-1.2.0.raucb",
  "size": 52428800,
  "sha256": "abc123...",
  "released_at": "2024-01-15T10:30:00"
}
```

### Installing updates

RAUC streams the bundle directly over HTTP/2 using its nbd client:

```bash
rauc install https://ota-gw.local:8443/bundles/update-1.2.0.raucb
```

Verify a remote bundle without installing:

```bash
rauc info https://ota-gw.local:8443/bundles/update-1.2.0.raucb
```

## API Reference

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/` | GET | - | Dashboard |
| `/api/v1/manifest.json` | GET | mTLS | Manifest for devices |
| `/api/manifest` | GET | - | Manifest for dashboard |
| `/api/bundles` | GET | - | List bundles |
| `/bundles/{name}` | GET | mTLS | Download bundle |
| `/upload` | POST | - | Upload bundle |
| `/activate/{name}` | POST | - | Activate bundle |
| `/delete/{name}` | POST | - | Delete bundle |
| `/health` | GET | - | Health check |

## License

MIT License
