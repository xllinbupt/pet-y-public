#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

codex_home="${CODEX_HOME:-$HOME/.codex}"
target="$codex_home/skills/pet-y"

mkdir -p "$codex_home/skills"
mkdir -p "$target"
cp pet-y-skill/SKILL.md "$target/SKILL.md"

echo "Installed Pet Y Skill to $target"
