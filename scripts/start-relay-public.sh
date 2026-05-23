#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8787}"

exec node server.js
