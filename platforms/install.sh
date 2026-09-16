#!/usr/bin/env bash
# sansheng-distill -- 共享安装器(DSH / Codex / Claude Code)
#
# 本仓的根目录就是 skill 目录(SKILL.md 在根上),三端都直接吃这一份。
# 安装 = 把它放进当前平台的 skills 根,默认用符号链接(改本仓即时生效)。
#
# 用法:
#   platforms/install.sh --platform dsh|codex|claude [--copy] [--force] [--uninstall]
#
#   --copy       复制而非软链(适合把 skill 固定在某处,或平台不支持软链)
#   --force      目标已存在时先删除再装(不加则拒绝覆盖)
#   --uninstall  移除安装(只删软链 / 复制来的目录,绝不动本仓)
set -euo pipefail

PLATFORM=""
MODE="link"
FORCE=0
UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --platform) PLATFORM="${2:-}"; shift 2 ;;
    --copy)     MODE="copy"; shift ;;
    --force)    FORCE=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help)  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

case "$PLATFORM" in
  dsh)    SKILLS_ROOT="${DSH_AGENTS_HOME:-$HOME/.agents}/skills" ;;
  codex)  SKILLS_ROOT="${CODEX_HOME:-$HOME/.codex}/skills" ;;
  claude) SKILLS_ROOT="${CLAUDE_HOME:-$HOME/.claude}/skills" ;;
  *) echo "必须用 --platform 指定 dsh | codex | claude" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_NAME="sansheng-distill"
DEST="$SKILLS_ROOT/$SKILL_NAME"

if [ "$UNINSTALL" -eq 1 ]; then
  if [ -L "$DEST" ]; then
    rm "$DEST"; echo "已移除软链: $DEST"
  elif [ -d "$DEST" ]; then
    rm -rf "$DEST"; echo "已移除目录: $DEST"
  else
    echo "未安装,无需移除: $DEST"
  fi
  exit 0
fi

# 前置检查:本仓必须真的是一个 skill 目录
if [ ! -f "$REPO_ROOT/SKILL.md" ]; then
  echo "错误:在 $REPO_ROOT 找不到 SKILL.md,这不是 skill 仓根目录。" >&2
  exit 1
fi

mkdir -p "$SKILLS_ROOT"

if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  if [ "$FORCE" -eq 1 ]; then
    rm -rf "$DEST"; echo "已覆盖旧安装: $DEST"
  else
    echo "目标已存在: $DEST" >&2
    echo "要覆盖请加 --force,或先跑 --uninstall。" >&2
    exit 1
  fi
fi

if [ "$MODE" = "copy" ]; then
  # 只复制 skill 运行所需的东西,跳过仓库自身的 git 元数据
  mkdir -p "$DEST"
  for item in SKILL.md references scripts templates assets LICENSE; do
    [ -e "$REPO_ROOT/$item" ] && cp -R "$REPO_ROOT/$item" "$DEST/"
  done
  echo "已复制安装: $DEST"
else
  ln -s "$REPO_ROOT" "$DEST"
  echo "已软链安装: $DEST -> $REPO_ROOT"
fi

echo
echo "平台: $PLATFORM"
echo "skills 根: $SKILLS_ROOT"
echo "调用入口: $DEST/SKILL.md"

# 平台专属的收尾提示
case "$PLATFORM" in
  dsh)
    echo
    echo "下一步:重启 DSH,本 skill 会被自动发现。"
    echo "想调整 skills 根,设环境变量 DSH_AGENTS_HOME 后重跑本脚本。"
    ;;
  codex)
    echo
    echo "建议在 ~/.codex/config.toml 里打开这两项:"
    echo
    echo "    [features]"
    echo "    multi_agent = true     # 让 Step2·Pass2 能 spawn_agent 并行 fan-out"
    echo "    web_search  = \"live\"    # 让 Step3 联网增补有实时搜索"
    echo
    echo "不开也能用:Pass2 退化为主控串行逐组执行(产物与门禁不变,只是变慢),"
    echo "Step3 走缓存索引搜索。然后重启 Codex。"
    ;;
  claude)
    echo
    echo "下一步:重启 Claude Code。"
    echo "(也可以改用 plugin marketplace 安装,见 README。) "
    ;;
esac
