# RAUC Simple Server

A lightweight OTA update server for [RAUC](https://rauc.io) with mTLS device authentication and a modern web dashboard.

## Features

- **Web Dashboard** — Upload bundles, activate releases, drag-and-drop support
- **mTLS Authentication** — Secure device-to-server communication with client certificates
- **REST API** — Simple JSON manifest for device polling
- **Docker Deployment** — Single `docker compose up` to run
- **Dark/Light Theme** — Modern, responsive UI

## Quick Start

```bash
# Clone the repo
git clone https://github.com/umair-uas/simple-ota-server.git
cd simple-ota-server

# Configure
cp .env.example .env
vim .env  # Set SERVER_URL and COMPATIBLE

# Generate certificates
./scripts/generate-certs.sh

# Start
docker compose up -d

# Open dashboard
open http://localhost:8080
```

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              NGINX                      │
                    │  ┌───────────────┐  ┌───────────────┐   │
  Devices ─────────►│  │  :8443 mTLS   │  │  :8080 HTTP   │◄──┼──── Admin
  (with certs)      │  │  Device API   │  │   Dashboard   │   │   (browser)
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

## Device Integration

Devices poll the manifest endpoint to check for updates:

```bash
curl --cert device.crt --key device.key --cacert ca.crt \
  https://<server>:8443/api/v1/manifest.json
```

Response:
```json
{
  "bundle_url": "https://<server>:8443/bundles/update-1.2.0.raucb",
  "compatible": "my-device-type",
  "filename": "update-1.2.0.raucb",
  "size": 52428800,
  "sha256": "abc123...",
  "released_at": "2024-01-15T10:30:00"
}
```

Install with RAUC:
```bash
rauc install https://<server>:8443/bundles/update-1.2.0.raucb
```

## Certificates

Generate development certificates (stable DNS SAN + current IP SAN):

```bash
./scripts/generate-certs.sh certs ota-gw.local 192.168.0.193
```

Ensure devices can resolve `ota-gw.local` (router DNS, mDNS, or `/etc/hosts`).

Generate device certificates:

```bash
./scripts/generate-device-cert.sh <device-id>
# Creates: certs/devices/<device-id>.crt, <device-id>.key
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
