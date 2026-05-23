#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
if ! curl -fsS --max-time 2 "http://127.0.0.1:8787/api/bootstrap?user=alice" >/dev/null; then
  echo "Relay 未连接。请先在另一个终端运行：npm start"
  exit 1
fi
npm run build:desktop >/dev/null
exec .build/PetYDesktop --user alice --relay http://127.0.0.1:8787
