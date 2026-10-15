#!/usr/bin/env bash
# Startet den Test-Zugang (gateway.py) auf 127.0.0.1:${PORT:-8095}.
# Erwartet die Umgebungsvariablen aus der beta.env (siehe README.md).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
cd "$repo/backend"
export PYTHONPATH="$repo/backend${PYTHONPATH:+:$PYTHONPATH}"
exec "$repo/backend/.venv/bin/uvicorn" gateway:app \
  --app-dir "$here" --host 127.0.0.1 --port "${PORT:-8095}" \
  --proxy-headers --forwarded-allow-ips 127.0.0.1 --no-server-header
