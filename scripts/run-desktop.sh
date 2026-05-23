#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

relay="${PET_Y_RELAY:-http://127.0.0.1:8787}"
args=(--relay "$relay")

if [[ -n "${PET_Y_USER:-}" ]]; then
  args+=(--user "$PET_Y_USER")
fi

if [[ -n "${PET_Y_LIFE_PACK:-}" ]]; then
  args+=(--life-pack "$PET_Y_LIFE_PACK")
fi

if ! curl -fsS --max-time 2 "$relay/api/health" >/dev/null; then
  echo "Relay 未连接。请先运行 npm start，或设置 PET_Y_RELAY 指向公网 Relay。"
  exit 1
fi

runtime="${PET_Y_RUNTIME:-}"
if [[ -z "$runtime" ]]; then
  if [[ -x "bin/PetYDesktop" ]]; then
    runtime="bin/PetYDesktop"
  elif [[ -x ".build/PetYDesktop" ]]; then
    runtime=".build/PetYDesktop"
  fi
fi

if [[ -z "$runtime" || ! -x "$runtime" ]]; then
  echo "没有找到 Pet Y Runtime。请先运行：./scripts/install-runtime.sh"
  echo "开发者也可以运行：npm run build:desktop"
  exit 1
fi

exec "$runtime" "${args[@]}"
