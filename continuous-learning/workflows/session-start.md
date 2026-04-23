# 会话启动 — 上下文加载

每次新对话开始时运行，从学习库中加载相关知识。

## 触发条件

新对话开始。

## 步骤

### 1. 快速状态检查

读取 `~/.claude/learning/.index.json`。如果库为空（session_count=0），静默跳过。

### 2. 加载相关模式

读取 `~/.claude/learning/patterns/` 中 `status=active` 的 L2 模式：
- 如果当前工作目录匹配某模式的 `domain` → 展示该模式
- 如果某模式 `confidence=high` 且 `status=active` → 标记待晋升

### 3. 检查未捕获的会话

读取 `~/.claude/learning/session-log.jsonl`——寻找 `messages ≥ 8` 但在 `sessions/` 中没有对应 L1 文件的记录。这些是 Stop hook 记录了元数据但 AI 捕获未运行的会话（如对话突然结束）。

### 4. 简短状态行

如果有可操作的信息，输出：
```
[学习] L1:{N} L2:{N} L3:{N} | {可操作事项}
```

示例：
- `[学习] L1:12 L2:3 L3:1 | 模式"并行Agent"可以晋升`
- `[学习] L1:5 L2:1 L3:0 | 发现2个未捕获的会话`

如果没有可操作事项：不输出任何内容，不要干扰会话开始。
