# Continuous Learning — 开发者知识编译器

三层知识管道，将日常编码会话自动沉淀为可复用的规则和技能。

```
日常对话 ══📝▷ L1 会话摘要 ══🔍▷ L2 开发模式 ══⬆️▷ L3 规则/技能
              每次会话结束      扫描聚类         置信度达标
```

## 原理

### 为什么需要这个技能

claude-mem 记录了**发生了什么**（事件观察），但不会提炼**这意味着什么**。  
本技能补全这条链路：将分散的会话经验编译为持久的行为准则。

### 三层模型

| 层级 | 存储位置 | 内容 | 触发方式 |
|------|---------|------|---------|
| **L1 会话摘要** | `~/.claude/learning/sessions/` | 一次会话做了什么、什么有效、什么失败、核心洞察 | 每次会话结束自动捕获 |
| **L2 开发模式** | `~/.claude/learning/patterns/` | 跨会话的方法论（不是事件复述）| ≥2个L1聚类时自动提炼 |
| **L3 规则/技能** | `~/.claude/rules/common/learned/` 或 `~/.claude/skills/learned/` | 可操作的行为准则 | L2 证据≥5条自动晋升 |

### 自动管道

三步在**同一时刻**（会话结束时）顺序执行，不是三个独立事件：

```
会话结束
  ├─ ① 捕获：提取本次会话 L1 摘要（≥8条消息或有调试/纠正/新方法）
  ├─ ② 提炼：扫描全部 L1 文件，按领域/标签聚类，≥2个则建/更新 L2
  ├─ ③ 晋升：扫描全部 L2 文件，数证据条数，≥5条 → 写入 rules/
  └─ ④ 刷新看板
```

### 关键约束

- **L2 提炼方法论，不复述事件**：问"什么思维方式导致了这个结果"而非"发生了什么"
- **不跳层**：每个 L2 必须引用 ≥2 个 L1 作为证据
- **L3 比 L2 更具体**：规则是可操作的指令，不是模式的换一种说法
- **证据链可追溯**：L3 → L2 → L1 每一层都能追溯到原始会话

## 依赖项

| 依赖 | 用途 | 必须？ |
|------|------|--------|
| `bash` | 所有脚本执行 | 是（macOS/Linux 内置） |
| `python3` | JSON 解析、看板数据提取 | 是（`evaluate-session.sh` 和 `dashboard.sh` 依赖） |
| `grep` | 会话 transcript 中统计消息数 | 是（内置） |
| Claude Code | 技能宿主、Stop hook 执行 | 是 |

不依赖：`sqlite3`、`jq`、`node`。

## 安装步骤

### 1. 复制技能目录

```bash
# 在目标机器上执行
cp -r /path/to/continuous-learning ~/.claude/skills/continuous-learning

# 确保脚本有执行权限
chmod +x ~/.claude/skills/continuous-learning/evaluate-session.sh
chmod +x ~/.claude/skills/continuous-learning/dashboard.sh
```

### 2. 创建 vault 目录结构

```bash
mkdir -p ~/.claude/learning/{sessions,patterns/{.archive},candidates}
mkdir -p ~/.claude/rules/common/learned
mkdir -p ~/.claude/skills/learned
```

### 3. 初始化索引文件

```bash
cat > ~/.claude/learning/.index.json << 'EOF'
{
  "last_capture": null,
  "session_count": 0,
  "pattern_count": 0,
  "rule_count": 0,
  "skill_count": 0,
  "pending_reviews": []
}
EOF
```

### 4. 注册 Stop hook

编辑 `~/.claude/settings.json`，在 `hooks` 字段中添加：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/skills/continuous-learning/evaluate-session.sh"
          }
        ]
      }
    ]
  }
}
```

> 如果 `hooks` 已有其他内容，将 `Stop` 数组合并进去，不要覆盖。

### 5. 验证安装

```bash
# 测试 Stop hook 脚本
echo '{}' | ~/.claude/skills/continuous-learning/evaluate-session.sh
cat ~/.claude/learning/session-log.jsonl
# 应该看到一行 JSON 日志

# 测试看板生成
bash ~/.claude/skills/continuous-learning/dashboard.sh --open
# 应该在浏览器中打开空白看板
```

### 6.（可选）迁移已有知识

如果要从旧机器带走已积累的知识：

```bash
# 在旧机器上
tar czf learning-vault.tar.gz -C ~/.claude learning/

# 在新机器上
tar xzf learning-vault.tar.gz -C ~/.claude/
```

## 文件清单

```
~/.claude/skills/continuous-learning/     # 技能本体
├── SKILL.md                              # 技能定义（Claude Code 加载此文件）
├── evaluate-session.sh                   # Stop hook 脚本（会话结束时记录元数据）
├── dashboard.sh                          # 看板生成器（生成 HTML 到 vault）
├── README.md                             # 本文件
└── workflows/
    ├── auto-pipeline.md                  # 全管道 ①②③（会话结束自动执行）
    ├── auto-capture.md                   # 捕获阶段参考（已合并入 auto-pipeline）
    ├── distill.md                        # 交互式提炼（手动触发）
    ├── review.md                         # 交互式复盘（手动触发）
    ├── status.md                         # 健康检查
    └── session-start.md                  # 会话启动时加载上下文

~/.claude/learning/                       # 知识 vault（数据目录）
├── sessions/                             # L1 会话摘要
├── patterns/                             # L2 开发模式
│   └── .archive/                         # 已退役的模式
├── candidates/                           # L2→L3 暂存区
├── session-log.jsonl                     # Stop hook 原始日志
├── .index.json                           # 元数据索引
└── dashboard.html                        # 生成的可视化看板

~/.claude/rules/common/learned/           # L3 输出：规则
~/.claude/skills/learned/                 # L3 输出：技能
```

## 配置说明

### settings.json 中的 Stop hook

```json
"hooks": {
  "Stop": [{
    "matcher": "*",
    "hooks": [{ "type": "command", "command": "~/.claude/skills/continuous-learning/evaluate-session.sh" }]
  }]
}
```

- `matcher: "*"` 表示所有会话都触发
- 脚本只做轻量元数据记录（统计消息数、记录时间戳），不做 AI 分析
- AI 分析由 `auto-pipeline.md` 在会话内执行

### SKILL.md 中的 auto-trigger

```yaml
auto-trigger: At conversation end, auto-run full pipeline (capture → distill → review)
```

这告诉 Claude Code 在会话结束时自动加载并执行此技能的管道工作流。

### 快捷指令

在对话中直接输入即可触发：

| 输入 | 效果 |
|------|------|
| `save` | 立即执行 ①②③ 全管道 |
| `提炼` | 交互式引导提炼 |
| `复盘` | 交互式模式复盘 |
| `看板` | 打开可视化看板 |
| `学习状态` | 健康检查 |

### 路径说明

所有路径均使用 `~` 或 `$HOME`，**无硬编码绝对路径**，可直接跨机器迁移。

## 与现有系统的关系

| 系统 | 角色 | 关系 |
|------|------|------|
| **claude-mem** | 会话级事件观察 | L0 原材料，本技能读取但不写入 |
| **auto-memory** | user/feedback/project/reference 记忆 | 补充 L2 模式识别的输入 |
| **~/.claude/rules/** | 全局行为规则 | L3 规则的输出目标 |
| **~/.claude/skills/learned/** | 自动生成的技能 | L3 技能的输出目标 |
| **claude-hud** | 状态栏显示 | 无直接关系 |
