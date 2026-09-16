#!/usr/bin/env bash
# 装进 DSH:~/.agents/skills/sansheng-distill(可用 DSH_AGENTS_HOME 覆盖)
# 用法: bash platforms/dsh/install.sh [--copy] [--force] [--uninstall]
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install.sh" --platform dsh "$@"
