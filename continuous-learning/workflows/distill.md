# 知识提炼工作流

引导式提炼：从会话（L1）经模式（L2）到规则/技能（L3）。

## 触发条件

用户说："distill" / "提炼" / "沉淀" / "总结经验"

## 第一阶段：扫描 L1 会话

1. 读取 `~/.claude/learning/sessions/` 中的所有文件
2. 按 `domain` 标签分组
3. 识别 ≥2 个会话共享以下特征的聚类：
   - 相同领域
   - 相似的洞察或失败模式
   - 重叠的文件路径或工具
4. 向用户展示聚类：

```
发现 {N} 个有潜在模式的会话聚类：

1. [{领域}] {主题} — {N} 个会话
   - {会话1日期}：{标题}
   - {会话2日期}：{标题}
   关键重叠：{共同点}

2. ...

要提炼哪个聚类？（输入编号或 "all"）
```

## 第二阶段：提升为 L2 模式

对选中的每个聚类，创建/更新 L2 文件 `~/.claude/learning/patterns/{slug}.md`：

```markdown
---
created: YYYY-MM-DD
updated: YYYY-MM-DD
domain: {领域}
confidence: low|medium|high
evidence_count: N
status: active|candidate|promoted
---

# 模式：{具体的、可操作的标题}

## 观察
{跨会话反复出现的规律——要具体，不要笼统}

## 证据
| 日期 | 会话 | 发生了什么 |
|------|------|-----------|
| YYYY-MM-DD | [会话名](../sessions/file.md) | {具体证据} |
| ... | ... | ... |

## 适用条件
- 适用：{具体上下文}
- 不适用：{反例或边界}

## 置信度评估
- **low**：2 个会话，需要更多证据
- **medium**：3-4 个会话，模式清晰但尚未作为规则验证
- **high**：5+ 个会话或用户明确确认，可以晋升
```

### 置信度规则
- 2 个证据 → `low`
- 3-4 个证据 → `medium`
- 5+ 个证据 或 用户明确确认 → `high`

## 第三阶段：晋升为 L3（仅当 confidence=high）

**仅在置信度为 high 时执行。** 先征求用户确认。

### 晋升为规则

如果模式是行为准则：

1. 创建规则文件 `~/.claude/rules/common/learned/{slug}.md`：
```markdown
# {规则标题}

> 自动晋升自模式：{pattern-slug}（{evidence_count} 个会话）
> 晋升日期：YYYY-MM-DD

{一段话描述规则——必须比 L2 模式更具体、更可操作。}

## 何时适用
- {具体触发条件}

## 何时不适用
- {边界条件/例外}

## 证据来源
来自 {N} 个会话，跨越 {日期范围}。详见 `~/.claude/learning/patterns/{slug}.md`。
```

2. 将模式状态更新为 `promoted`
3. 更新 `.index.json` 规则计数

### 晋升为技能

如果模式是可复用的工作流/技术：

1. 创建技能 `~/.claude/skills/learned/{slug}.md`：
```markdown
---
name: {slug}
description: {一句话描述}
---

# {技能标题}

> 自动晋升自模式：{pattern-slug}

## 何时使用
{触发条件}

## 步骤
1. {步骤1}
2. {步骤2}
...

## 证据来源
来自 {N} 个会话。详见 `~/.claude/learning/patterns/{slug}.md`。
```

2. 将模式状态更新为 `promoted`

## 第四阶段：总结

输出：
```
提炼完成：
- 扫描会话：{N} 个
- 创建/更新模式：{N} 个
- 晋升为规则：{N} 个
- 晋升为技能：{N} 个
- 待复盘（medium 置信度）：{列表}
```
