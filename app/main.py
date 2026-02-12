#!/usr/bin/env python3
"""
RAUC Simple Server - OTA update server with mTLS and web dashboard.
"""
import os
import json
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, Request, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI(title="RAUC Simple Server", version="1.0.0")

# Configuration
DATA_DIR = Path(os.environ.get('DATA_DIR', '/data'))
BUNDLES_DIR = DATA_DIR / 'bundles'
SERVER_URL = os.environ.get('SERVER_URL', 'https://localhost:8443')
COMPATIBLE = os.environ.get('COMPATIBLE', 'iot-gateway-raspberrypi5')

# Ensure directories exist
BUNDLES_DIR.mkdir(parents=True, exist_ok=True)

# Static files
STATIC_DIR = Path('/app/static')
app.mount('/static', StaticFiles(directory=STATIC_DIR), name='static')


# =============================================================================
# Helpers
# =============================================================================

def require_mtls(request: Request) -> None:
    """Verify request came through mTLS."""
    if request.headers.get('X-SSL-Client-Verify') != 'SUCCESS':
        raise HTTPException(status_code=403, detail='mTLS client certificate required')


def get_manifest() -> dict:
    """Get current manifest from file or return empty state."""
    manifest_file = DATA_DIR / 'manifest.json'
    if manifest_file.exists():
        return json.loads(manifest_file.read_text())

    # Auto-detect latest bundle if no manifest
    bundles = sorted(BUNDLES_DIR.glob('*.raucb'), key=lambda p: p.stat().st_mtime, reverse=True)
    if bundles:
        bundle = bundles[0]
        return {
            'bundle_url': f'{SERVER_URL}/bundles/{bundle.name}',
            'compatible': COMPATIBLE,
            'filename': bundle.name,
            'size': bundle.stat().st_size,
            'sha256': hash_file(bundle),
            'released_at': datetime.fromtimestamp(bundle.stat().st_mtime).isoformat(),
        }

    return {'bundle_url': '', 'compatible': COMPATIBLE, 'filename': ''}


def save_manifest(manifest: dict) -> None:
    """Save manifest to file."""
    (DATA_DIR / 'manifest.json').write_text(json.dumps(manifest, indent=2))


def secure_filename(filename: str) -> str:
    """Sanitize filename for safe filesystem storage."""
    filename = filename.replace('/', '').replace('\\', '').replace('\x00', '')
    return ''.join(c for c in filename if c.isalnum() or c in '._-')


def hash_file(filepath: Path, chunk_size: int = 8192) -> str:
    """Calculate SHA256 hash using streaming."""
    sha256 = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(chunk_size):
            sha256.update(chunk)
    return sha256.hexdigest()


# =============================================================================
# Device API (mTLS required - port 8443)
# =============================================================================

@app.get('/api/v1/manifest.json')
async def api_manifest(request: Request):
    """Return update manifest for devices (mTLS required)."""
    require_mtls(request)
    return get_manifest()


@app.get('/bundles/{filename}')
async def serve_bundle(filename: str, request: Request):
    """Serve bundle file (mTLS required)."""
    require_mtls(request)
    filepath = BUNDLES_DIR / secure_filename(filename)
    if not filepath.exists():
        raise HTTPException(status_code=404, detail='Bundle not found')
    return FileResponse(filepath, filename=filename, media_type='application/octet-stream')


# =============================================================================
# Dashboard (localhost only - port 8080)
# =============================================================================

@app.get('/')
async def dashboard():
    """Serve dashboard."""
    return FileResponse(STATIC_DIR / 'index.html')


@app.get('/api/manifest')
async def api_manifest_dashboard():
    """Return manifest for dashboard."""
    return get_manifest()


@app.get('/api/bundles')
async def api_bundles():
    """List all bundles."""
    return [
        {
            'name': b.name,
            'size': b.stat().st_size,
            'mtime': datetime.fromtimestamp(b.stat().st_mtime).isoformat(),
        }
        for b in BUNDLES_DIR.glob('*.raucb')
    ]


@app.post('/upload')
async def upload_bundle(bundle: UploadFile = File(...), activate: Optional[str] = Form(None)):
    """Upload a bundle."""
    if not bundle.filename:
        raise HTTPException(status_code=400, detail='No file selected')
    if not bundle.filename.endswith('.raucb'):
        raise HTTPException(status_code=400, detail='File must be a .raucb bundle')

    filename = secure_filename(bundle.filename)
    filepath = BUNDLES_DIR / filename

    # Stream to disk
    sha256 = hashlib.sha256()
    with open(filepath, 'wb') as f:
        while chunk := await bundle.read(8192):
            f.write(chunk)
            sha256.update(chunk)

    if activate == 'true':
        save_manifest({
            'bundle_url': f'{SERVER_URL}/bundles/{filename}',
            'compatible': COMPATIBLE,
            'filename': filename,
            'size': filepath.stat().st_size,
            'sha256': sha256.hexdigest(),
            'released_at': datetime.now().isoformat(),
        })

    return RedirectResponse(url='/', status_code=303)


@app.post('/activate/{filename}')
async def activate_bundle(filename: str):
    """Set bundle as active."""
    safe_filename = secure_filename(filename)
    filepath = BUNDLES_DIR / safe_filename
    if not filepath.exists():
        raise HTTPException(status_code=404, detail='Bundle not found')

    save_manifest({
        'bundle_url': f'{SERVER_URL}/bundles/{safe_filename}',
        'compatible': COMPATIBLE,
        'filename': safe_filename,
        'size': filepath.stat().st_size,
        'sha256': hash_file(filepath),
        'released_at': datetime.now().isoformat(),
    })
    return RedirectResponse(url='/', status_code=303)


@app.post('/delete/{filename}')
async def delete_bundle(filename: str):
    """Delete a bundle."""
    safe_filename = secure_filename(filename)
    filepath = BUNDLES_DIR / safe_filename
    if filepath.exists():
        filepath.unlink()
        manifest_file = DATA_DIR / 'manifest.json'
        if manifest_file.exists():
            try:
                if json.loads(manifest_file.read_text()).get('filename') == safe_filename:
                    manifest_file.unlink()
            except Exception:
                pass
    return RedirectResponse(url='/', status_code=303)


@app.get('/health')
async def health():
    """Health check."""
    return {'status': 'ok'}
