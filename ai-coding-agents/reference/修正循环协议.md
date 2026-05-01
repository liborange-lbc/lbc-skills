# 修正循环协议

> Phase 4（系分评审）和 Phase 6（代码CR）共用。主Agent执行。

## 判定流程

```
收到评审报告
  ↓
主Agent Grep 提取: "### 判定" 行 → PASS/FAIL
主Agent Grep 提取: "CRITICAL: N" "HIGH: N" 统计行
  ↓ FAIL
分类问题 → 选择回退深度 → 修正 → 重新评审
  ↓
最多 MAX_ITERATION 轮
  ↓ 超限
标记残留问题 ⚠️ → 列入交付报告风险项 → 用户决定
```

## 问题分类与回退

| 问题性质 | 判定标准 | 回退到 |
|----------|----------|--------|
| **局部问题** | 集中在具体章节/函数，不影响整体 | Resume 原Agent 定点修复 → 重新评审 |
| **架构级问题** | 分层/边界/核心流程有根本缺陷 | 回退上一阶段重做 → 重新评审 |
| **需求理解错误** | 方向与业务目标偏离 | 回退 Phase 1 → 全流程重来 |

## Resume 机制

### 核心原理

Claude Code 的 Agent 工具返回 `agentId`。用 `SendMessage(to: agentId)` 可恢复同一子Agent的完整对话历史，子Agent能回忆起之前的设计决策和实现细节，修正效率远高于新建。

### 操作步骤

**Step 1: 首次启动时记录 agentId**

```
# 主Agent启动 designer 子Agent
result = Agent(prompt: "根据需求清单编写系分文档...", subagent_type: "designer")

# 从返回结果中提取 agentId（结果末尾会包含 agentId 信息）
# 立即记录到执行日志:
→ 写入 log/执行日志.md: "260501 0945 Phase 3 designer 启动 (agentId: abc123)"
```

**Step 2: 修正循环中 Resume**

```
# 评审发现问题，Resume 同一 designer
SendMessage(
  to: "abc123",                    # 使用记录的 agentId
  message: "评审发现以下问题需要修复:
    1. [CRITICAL] R05 未在系分中覆盖，请补充 §4.3 接口设计
    2. [HIGH] §3.2 缺少幂等机制说明
    评审报告路径: {需求目录}/log/phase4-评审-需求完整度.md
    请逐条修复后更新系分文档。"
)
```

**Step 3: Resume reviewers 重新评审**

```
# 同样 Resume 评审子Agent（不新建）
SendMessage(to: "{reviewer_agentId}", message: "designer 已修复问题，请重新评审系分文档")
```

### Resume vs 新建的选择

| 场景 | 操作 | 原因 |
|------|------|------|
| 局部问题修正 | **SendMessage Resume** | 保留上下文，子Agent理解"为什么当初这样写" |
| 架构级回退重做 | **新建 Agent** | 原设计方向错误，需要全新视角 |
| 跨Phase切换 | **新建 Agent** | 不同角色、不同职责 |
| reviewers 重新评审 | **SendMessage Resume** | 保留之前的评审发现，只检查修复项 |

### 注意事项

1. **agentId 必须记录** — 写入执行日志，修正循环时查找
2. **不传全文** — 传评审报告路径，让子Agent自行读取（节省上下文）
3. **传具体修复指令** — "修复以下N个问题:..."，不要说"看报告自己修"
4. **每个Phase的agentId独立** — designer/coder/reviewer 各有各的ID

## 经验库沉淀

每次修正循环中发现的可复用模式，追加到 `经验库.md`:

```markdown
## {类别}
- {可复用模式描述，不记具体行号}
```

**抽象规则**:
- ❌ 太具体: "page03 第42行 left 应该是 120"
- ❌ 太模糊: "代码要写好"
- ✅ 合适: "分页查询必须处理空结果，否则上层 map 报 NPE"

## 迭代日志

写入 `log/phase{N}-迭代-{轮次}.md`:

```markdown
# 第 {N} 轮修正

## 修复清单
| # | 原问题 | 修复内容 | 状态 |
|---|--------|---------|------|
| 1 | R05未覆盖 | 补充§3.3接口设计 | ✅ |

## 重新评审结果
- CRITICAL: 0 | HIGH: 0 | 需求覆盖: 100%
- 判定: PASS
```
