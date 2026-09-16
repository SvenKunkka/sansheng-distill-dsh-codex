#!/usr/bin/env bash
# 装进 Codex:~/.codex/skills/sansheng-distill(可用 CODEX_HOME 覆盖)
# 用法: bash platforms/codex/install.sh [--copy] [--force] [--uninstall]
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install.sh" --platform codex "$@"
