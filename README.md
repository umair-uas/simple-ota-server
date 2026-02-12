# RAUC Simple Server

A lightweight OTA update server for [RAUC](https://rauc.io) with mTLS device authentication and a modern web dashboard.

**Perfect for:** Small deployments, development/testing, or as a starting point for custom OTA infrastructure.

For large fleets (100+ devices), consider [Eclipse hawkBit](https://github.com/eclipse/hawkbit) with [rauc-hawkbit-updater](https://github.com/rauc/rauc-hawkbit-updater).

## Features

- **Web Dashboard** — Upload bundles, activate releases, drag-and-drop support
- **mTLS Authentication** — Secure device-to-server communication with client certificates
- **REST API** — Simple JSON manifest for device polling
- **Docker Deployment** — Single `docker compose up` to run
- **Dark/Light Theme** — Modern, responsive UI with collapsible sidebar

## Quick Start

```bash
# Clone the repo
git clone https://github.com/umair-uas/simple-ota-server.git
cd simple-ota-server

# Configure
cp .env.example .env
vim .env  # Set SERVER_URL and COMPATIBLE

# Generate certificates (or use your own)
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

## Ports

| Port | Protocol | Auth | Purpose |
|------|----------|------|---------|
| 8443 | HTTPS | mTLS (client cert) | Device API |
| 8080 | HTTP | None | Admin dashboard |

## Configuration

Edit `.env`:

```bash
# URL devices use to download bundles (must be reachable from devices)
SERVER_URL=https://192.168.1.100:8443

# RAUC compatible string (must match device's /etc/rauc/system.conf)
COMPATIBLE=my-device-type
```

## Device Integration

### Manifest API

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

### Install Update

With RAUC's HTTP streaming (RAUC 1.7+):
```bash
rauc install https://<server>:8443/bundles/update-1.2.0.raucb
```

Or download first:
```bash
curl -O https://<server>:8443/bundles/update-1.2.0.raucb
rauc install update-1.2.0.raucb
```

## Certificates

The server requires TLS certificates in `certs/`:

| File | Purpose |
|------|---------|
| `ca.crt` | CA certificate (verifies device client certs) |
| `ca.key` | CA private key (signs device certs) |
| `server.crt` | Server certificate |
| `server.key` | Server private key |

### Generate Development Certificates

```bash
./scripts/generate-certs.sh
```

### Generate Device Certificates

```bash
./scripts/generate-device-cert.sh <device-id>
# Creates: certs/devices/<device-id>.crt, <device-id>.key
```

## Directory Structure

```
simple-ota-server/
├── app/main.py           # FastAPI application
├── static/index.html     # Dashboard UI
├── config/nginx.conf     # Nginx configuration
├── scripts/              # Certificate generation scripts
├── certs/                # TLS certificates (gitignored)
│   ├── ca.crt/key        # CA certificate
│   ├── server.crt/key    # Server certificate
│   └── devices/          # Device client certificates
├── data/                 # Runtime data (gitignored)
│   ├── manifest.json     # Current release
│   └── bundles/          # RAUC bundle storage
├── docker-compose.yml
├── Dockerfile
└── .env.example
```

## API Reference

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/` | GET | - | Dashboard |
| `/api/v1/manifest.json` | GET | mTLS | Current release manifest (for devices) |
| `/api/manifest` | GET | - | Current release manifest (for dashboard) |
| `/api/bundles` | GET | - | List all bundles |
| `/bundles/{name}` | GET | mTLS | Download bundle |
| `/upload` | POST | - | Upload bundle |
| `/activate/{name}` | POST | - | Activate bundle |
| `/delete/{name}` | POST | - | Delete bundle |
| `/health` | GET | - | Health check |

## Production Deployment

For production, consider:

1. **Reverse proxy** — Put behind nginx/traefik with proper TLS termination
2. **Persistent storage** — Mount `data/` to a persistent volume
3. **Backup** — Backup `data/manifest.json` and `certs/`
4. **Monitoring** — Add health check monitoring on `/health`

## Alternatives

| Solution | Best For | Complexity |
|----------|----------|------------|
| **This project** | Small deployments, testing | Low |
| [hawkBit](https://github.com/eclipse/hawkbit) | Large fleets, enterprise | High |
| [Mender](https://mender.io) | Managed service | Medium |
| [UpdateHub](https://updatehub.io) | Managed/self-hosted | Medium |

## License

MIT License — See [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please open an issue or PR.

## Related Projects

- [RAUC](https://github.com/rauc/rauc) — The update framework this server supports
- [rauc-hawkbit-updater](https://github.com/rauc/rauc-hawkbit-updater) — RAUC client for hawkBit
