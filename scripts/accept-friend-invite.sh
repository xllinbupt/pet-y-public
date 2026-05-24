#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

token="${1:-${PET_Y_INVITE_TOKEN:-}}"
relay="${PET_Y_RELAY:-http://127.0.0.1:8787}"
identity_file="${PET_Y_IDENTITY_FILE:-$HOME/Library/Application Support/PetY/identity.json}"

if [[ -z "$token" ]]; then
  echo "请提供好友邀请口令：./scripts/accept-friend-invite.sh <friend-invite-phrase>"
  exit 1
fi

if [[ ! -f "$identity_file" ]]; then
  echo "还没有本地身份。请先启动一次 Runtime：./scripts/run-desktop.sh"
  exit 1
fi

user_id="$(node -e "const fs=require('fs'); const p=process.argv[1]; console.log(JSON.parse(fs.readFileSync(p,'utf8')).user_id || '')" "$identity_file")"
if [[ -z "$user_id" ]]; then
  echo "本地身份里没有 user_id：$identity_file"
  exit 1
fi

body="$(node -e "console.log(JSON.stringify({user_id: process.argv[1], token: process.argv[2]}))" "$user_id" "$token")"
headers=(-H "content-type: application/json")
if [[ -n "${PET_Y_RELAY_SECRET:-}" ]]; then
  headers+=(-H "x-pet-y-relay-secret: $PET_Y_RELAY_SECRET")
fi

curl -fsS -X POST "$relay/api/friends/accept" \
  "${headers[@]}" \
  -d "$body" >/dev/null

echo "好友关系已绑定。请重启 Pet Y Runtime。"
