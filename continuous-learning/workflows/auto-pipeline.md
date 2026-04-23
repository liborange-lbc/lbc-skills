# 自动管道 — 会话结束全链路处理

会话结束时自动运行，执行完整的 L1→L2→L3 管道。

## 触发条件

对话即将结束。此工作流替代手动提炼/复盘，实现常规自动化运作。

## 第一阶段：捕获（L1）

### 1a. 评估价值

扫描对话内容，寻找以下信号：
- ≥8 条用户消息
- 调试了 bug 或解决了错误
- 尝试了新技术或新方法
- 用户给了纠正或反馈
- 完成了多文件实现
- 做了架构或设计决策

**如果没有任何信号 → 跳到第四阶段（仅刷新看板）。**

### 1b. 写入 L1 会话文件

创建 `~/.claude/learning/sessions/YYYY-MM-DD-{slug}.md`：

```markdown
---
date: YYYY-MM-DD
duration: ~Xm
domain: {项目/工具/语言领域}
signals: [匹配到的信号]
tags: [关键技术、模式、领域]
---

# 会话：{描述性标题}

## 完成的工作
- {1-3 条具体要点}

## 有效的方法
- {成功的方法，附带上下文}

## 失败或被纠正的部分
- {死胡同、用户纠正}

## 核心洞察
{一句话总结本次会话学到的非显而易见的东西。如果没有新发现："常规工作，无新洞察。"}
```

### 1c. 更新索引

在 `.index.json` 中递增 `session_count`，更新 `last_capture`。

## 第二阶段：自动提炼（L1→L2）

### 2a. 扫描聚类

读取所有 L1 会话文件，按 `domain` 和 `tags` 分组。寻找：
- ≥2 个会话共享同一领域
- ≥2 个会话有重叠标签
- ≥2 个会话有相似的核心洞察或失败模式

### 2b. 对每个聚类处理

**关键原则：提炼方法论，而非复述事件。**
L2 模式必须脱离具体事情本身，总结推进过程背后的思考方式和决策逻辑。
问自己："是什么思维方式/决策方法导致了这个结果？"而不是"发生了什么？"

> 反例：L1 说"为印章检测新增梯度变异系数"→ L2 写"梯度变异系数对印章有用" ❌（只是复述事件）
> 正例：L1 说"为印章检测新增梯度变异系数"→ L2 写"当单一判别器失效时，测量底层信号的变异系数——纹理一致性往往优于几何特征" ✅（提炼了方法论）

**如果没有匹配的已有 L2 模式：**
- 创建新 L2 模式文件 `~/.claude/learning/patterns/{slug}.md`：

```markdown
---
created: YYYY-MM-DD
updated: YYYY-MM-DD
domain: {领域}
confidence: low
evidence_count: 2
status: active
---

# 模式：{具体的、可操作的标题——描述方法论，而非具体事件}

## 观察
{跨会话反复出现的思维方式或决策逻辑——要抽象到可迁移的层面}

## 证据
| 日期 | 会话 | 发生了什么 |
|------|------|-----------|
| YYYY-MM-DD | [{slug}](../sessions/file.md) | {具体内容} |
| YYYY-MM-DD | [{slug}](../sessions/file.md) | {具体内容} |

## 适用条件
- 适用：{具体上下文}
- 不适用：{边界情况}

## 置信度：low（2 个会话）
```

**如果匹配到已有 L2 模式：**
- 在证据表中添加新行
- 递增 `evidence_count`
- 更新置信度：2=low，3-4=medium，5+=high
- 更新 `updated` 日期

### 2c. 更新索引

更新 `.index.json` 中的 `pattern_count` 和 `pending_reviews`。

## 第三阶段：自动复盘与晋升（L2→L3）

### 3a. 检查可晋升的模式

扫描所有 `confidence=high` 且 `status=active` 的 L2 模式。

### 3b. 自动晋升

对每个可晋升的模式，判断类型：

**如果是行为准则 → 规则：**

创建 `~/.claude/rules/common/learned/{slug}.md`：
```markdown
# {规则标题}

> 自动晋升自模式 [{slug}](~/.claude/learning/patterns/{slug}.md) | {evidence_count} 个会话 | {日期}

{可操作的规则描述——必须比 L2 模式观察更具体、更可执行。}

## 何时适用
- {触发条件}

## 何时不适用
- {例外情况}
```

**如果是可复用的工作流 → 技能：**

创建 `~/.claude/skills/learned/{slug}.md`：
```markdown
---
name: {slug}
description: {一句话描述}
---

# {技能标题}

> 自动晋升自模式 [{slug}](~/.claude/learning/patterns/{slug}.md)

## 何时使用
{条件}

## 步骤
1. {步骤}
2. {步骤}
```

### 3c. 更新模式状态

将已晋升的模式设为 `status: promoted`。更新 `.index.json` 中的 `rule_count`/`skill_count`。

## 第四阶段：生成看板与报告

### 4a. 刷新看板

运行：`bash ~/.claude/skills/continuous-learning/dashboard.sh`

更新 `~/.claude/learning/dashboard.html` 为最新状态。

### 4b. 单行报告

输出一行：
```
[学习] {会话标题或"已跳过"} | L1:{数量} L2:{数量} L3:{数量} | {变化说明，如"+1会话，模式'X'→medium"}
```

如果没有变化：不输出任何内容。
