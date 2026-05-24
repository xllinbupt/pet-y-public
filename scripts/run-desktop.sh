#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

relay="${PET_Y_RELAY:-http://127.0.0.1:8787}"
args=(--relay "$relay")
if [[ -n "${PET_Y_RELAY_SECRET:-}" ]]; then
  args+=(--relay-secret "$PET_Y_RELAY_SECRET")
fi
app_support="${PET_Y_APP_SUPPORT:-$HOME/Library/Application Support/PetY}"

if [[ -n "${PET_Y_USER:-}" ]]; then
  args+=(--user "$PET_Y_USER")
fi

life_pack="${PET_Y_LIFE_PACK:-}"
if [[ -z "$life_pack" ]]; then
  if [[ "${PET_Y_USER:-}" == "bob" ]]; then
    life_pack="life-packs/bob-yuzu/pet-life.json"
  else
    life_pack="life-packs/alice-momo/pet-life.json"
  fi
fi

if [[ -n "$life_pack" ]]; then
  source_life_pack="$life_pack"
  if [[ "$source_life_pack" != /* ]]; then
    source_life_pack="$PWD/$source_life_pack"
  fi
  if [[ -f "$source_life_pack" ]]; then
    source_dir="$(dirname "$source_life_pack")"
    pack_name="$(basename "$source_dir")"
    target_dir="$app_support/LifePacks/$pack_name"
    mkdir -p "$(dirname "$target_dir")"
    rm -rf "$target_dir.tmp"
    cp -R "$source_dir" "$target_dir.tmp"
    rm -rf "$target_dir"
    mv "$target_dir.tmp" "$target_dir"
    args+=(--life-pack "$target_dir/pet-life.json")
  else
    args+=(--life-pack "$life_pack")
  fi
fi

if ! curl -fsS --max-time 2 "$relay/api/health" >/dev/null; then
  echo "Relay 未连接。请先运行 npm start，或设置 PET_Y_RELAY 指向公网 Relay。"
  exit 1
fi

runtime="${PET_Y_RUNTIME:-}"
if [[ -z "$runtime" ]]; then
  if [[ -x "$app_support/Runtime/PetYDesktop" ]]; then
    runtime="$app_support/Runtime/PetYDesktop"
  elif [[ -x "bin/PetYDesktop" ]]; then
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
