# 平台适配层(DSH / Codex / Claude Code)

本 skill 的**管线、门禁、脚本、references 三端共用**;三端差异只在四件事:**装在哪、怎么调工具、怎么并行派 agent、怎么联网**。本文是这三层差异的唯一出处。

主管线(`SKILL.md`)里凡是写「运行环境无关」的动作(读文件 / 写文件 / 跑命令 / 联网检索 / 派 subagent),按本文映射到当前平台的具体工具名。

---

## 1. `$SKILL` 装在哪

`$SKILL` = **本 `SKILL.md` 的所在目录**。三端的默认位置:

| 平台 | 默认安装位置 | 发现方式 |
|---|---|---|
| **DSH** | `~/.agents/skills/sansheng-distill/`(可用 `$DSH_AGENTS_HOME/skills/` 覆盖) | 启动时扫描 skills 根,读每个子目录的 `SKILL.md` |
| **DSH(项目级)** | `<项目根>/.agents/skills/sansheng-distill/` 或 `<项目根>/.dsh/skills/sansheng-distill/` | 同上,项目级优先 |
| **Codex** | `~/.codex/skills/sansheng-distill/` | 启动时扫描 skills 根 |
| **Claude Code** | `~/.claude/skills/sansheng-distill/` | 目录 bundle 自动发现 |

三端都接受**同一份目录**(`SKILL.md` + `references/` + `scripts/` + `templates/` + `assets/`),所以安装方式都是「把本仓放进对应 skills 根」。安装脚本见 `platforms/dsh/install.sh` 与 `platforms/codex/install.sh`。

**`$SKILLS_HOME`** = 当前平台的 **skills 根目录**,即上表那一列(DSH 为 `~/.agents/skills`,Codex 为 `~/.codex/skills`,Claude Code 为 `~/.claude/skills`)。`method.md §V.0` 里引用配套 skill(`video-to-subtitle-summary`、`sansheng-gemini-video`)时用它拼路径:`$SKILLS_HOME/video-to-subtitle-summary/scripts/...`。

三端 frontmatter 都只强制要求 `name` + `description`;本 skill 的 frontmatter 正好只有这两个键,因此**同一份 `SKILL.md` 三端通用,不需要各自维护一份**。

> DSH 额外认识 `whenToUse` 与 `metadata`,不认识 `allowed-tools` / `model`(Claude Code 的键,DSH 静默忽略,不报错)。**不要把 Claude 专属键写进本 skill 的 frontmatter**,免得在别处触发校验告警。

---

## 2. 命令里的 Python 与路径

- **一律用正斜杠 `/`**。上游 Windows 版写的 `$SKILL\scripts\x.py` 已全部改为 `$SKILL/scripts/x.py`,在 macOS / Linux / Windows(PowerShell、Git Bash)下都能跑。
- **Python 解释器**:文档里写 `python`,若系统只有 `python3`(macOS / 多数 Linux),把 `python` 换成 `python3` 即可。脚本本身是 Python 3 标准库 + 依赖包,无版本锁定。
- **占位符替换**:命令里的 `$SKILL` / `$DATA` / `{slug}` / `{书目录}` 先替成实值再执行。

---

## 3. 工具映射表(核心)

主管线提到下列**动作**。左列是 Claude Code 的写法(本 skill 原文沿用它),中、右列是对应平台的实际工具:

| 动作 | Claude Code | **DSH** | **Codex** |
|---|---|---|---|
| 读文件 | `Read` | `read` | 原生文件工具 |
| 写文件 | `Write` | `write` | 原生文件工具 |
| 改文件 | `Edit` | `edit` | 原生文件工具 |
| 跑命令 | `Bash` | `bash` | 原生 shell |
| 列目录 / 找文件 | `Glob` | `glob` | 原生 shell(`ls` / `rg --files`) |
| 搜内容 | `Grep` | `grep` | 原生 shell(`rg`) |
| 任务清单 | `TodoWrite` | `todo_write` | `update_plan` |
| **派 subagent** | `Task` | **`subagent`**(后台运行,默认并发) | **`spawn_agent`**(需开 multi-agent,见 §4) |
| 取 subagent 结果 | `Task` 返回值 | 子代理结束后回传(或 `list_agents`) | `wait_agent` |
| 释放 subagent 槽位 | 自动 | 自动回收 | `close_agent` |
| **大规模 fan-out** | 多次 `Task` | **`workflow`**(脚本化编排,内置并发闸) | 多次 `spawn_agent` |
| **联网搜索** | `WebSearch` / MCP(AnySearch、Tavily) | **`web_search`** | **`web_search`**(见 §5) |
| **抓网页正文** | `WebFetch` | **`web_fetch`** | `web_search` 取回 + 原生 shell(`curl`) |
| 问用户 | `AskUserQuestion` | `ask_user_question` | 直接问 |

**关键**:主管线写「派 subagent 全 Opus」这类措辞时,在当前平台按上表换成对应工具即可。**并发闸(全局在飞 ≤6-8)在三端都成立**,不是 Claude 专属约束。

---

## 4. Codex 的 subagent 前提

Codex 的 `spawn_agent` / `wait_agent` / `close_agent` **默认不开**,需在 `~/.codex/config.toml` 加:

```toml
[features]
multi_agent = true
```

- **开了**:Step2·Pass2 的「长书按章 fan-out(每组 ≤5 章派 1 个 agent)」照常并行,与 Claude / DSH 一致。
- **没开**:`spawn_agent` 不可用。**不要跳过 Pass2**,改为**主控串行逐组执行**(自己按组顺序写 narrative,每组仍守 ≤5 章与全部质量门禁 G8-G22)。产物、命名(`_pass2_gN.json`)、合并完整性断言**完全不变**,只是墙钟变长。
- 无论哪种,`_pass2_gN.json` 的命名纪律与「合并后清理中间态」照旧执行。

> 参考:OpenAI 官方维护的 [Codex Tool Mapping](https://github.com/openai/plugins/blob/main/plugins/superpowers/skills/using-superpowers/references/codex-tools.md)(`Task` → `spawn_agent`,需 `multi_agent = true`;`TodoWrite` → `update_plan`)。

---

## 5. 联网检索(Step3 / StepA / StepB)三端怎么落

`enrich.md §3.4` 的降级链原本写的是 Claude Code 的 MCP 工具(`mcp__anysearch__search` → `tavily_search` → `WebSearch`,取正文用 `WebFetch`)。**降级链的语义(中文广搜 → 英文深搜 → 兜底;失败即降级、禁重试轰炸;外证必须带可点击 URL)在三端完全一致**,只换工具名:

| 档位 | Claude Code | DSH | Codex |
|---|---|---|---|
| 中文广搜 | `mcp__anysearch__search` | `web_search`(中文 query) | `web_search` |
| 英文深搜 / 定向域 | `tavily_search` / `tavily_research` | `web_search`(英文 query) | `web_search` |
| 兜底 | 内置 `WebSearch` | `web_search` | `web_search` |
| 取页面正文 | `WebFetch` | `web_fetch` | `web_search` 结果 + shell `curl` |

- **DSH**:`web_search` 一次可传 1-4 条 query(中英混发可合并成一次调用);正文用 `web_fetch`。若装了 MCP,`mcp__*` 工具同样可用,chain 不变。
- **Codex**:`web_search` 需启用 —— `config.toml` 里设 `web_search = "live"`(实时)或 `"indexed"`(缓存索引,默认),`"disabled"` 关闭;单次运行也可用 `codex --search "..."`。搜索记录在 transcript 里表现为 `web_search` 条目。
- **任一平台**:三档全抓不到 → 该块置 `null` **整块隐藏**(子视图 + 入口一并删),蒸馏主体不受影响。这条降级规则与平台无关。

---

## 6. 各平台一句话上手

**DSH**
```bash
bash platforms/dsh/install.sh          # 软链到 ~/.agents/skills/sansheng-distill
```
然后在 DSH 里说「蒸馏这本书」并给出电子书路径。

**Codex**
```bash
bash platforms/codex/install.sh        # 软链到 ~/.codex/skills/sansheng-distill
```
在 `~/.codex/config.toml` 开 `[features] multi_agent = true` 与 `web_search = "live"`(想并行 fan-out / 联网增补时需要),然后重启 Codex。

**Claude Code**
```bash
claude plugin marketplace add <owner>/sansheng-distill
claude plugin install sansheng-distill
```

---

## 7. 环境依赖(三端相同)

```bash
pip install ebooklib beautifulsoup4 pymupdf pillow playwright pytest
playwright install chromium     # Step7 出厂验证需要
```

- `.azw3` / `.mobi` 输入另需 calibre 的 `ebook-convert`;epub / pdf / txt 不需要。
- 视频系列路径另需 `yt-dlp`(抓字幕 + 评论);B站评论走公开 API 免依赖。
- 环境变量(`DISTILL_DATA_DIR` / `GOOGLE_API_KEY` / `AI_DOUYIN_API_KEY`)见仓根 `.env.example`,**三端通用**。
