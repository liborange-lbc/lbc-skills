# 执行日志规范

> 主Agent 维护 `{需求目录}/log/执行日志.md`。子Agent 各写独立 log 文件。

## 时间格式

`YYMMDD HHmm`，如 `260501 0930`

## 主Agent 执行日志

```markdown
# 执行日志 — {feature-name}

## 项目信息
- 启动时间: {datetime}
- 需求来源: {source}
- 配置: BATCH_SIZE={N}, MAX_ITERATION={N}
- GitNexus索引: {project-name}

## Agent 注册表

> 记录所有子Agent的 agentId，用于修正循环 Resume 和故障恢复。
> 每次启动子Agent后立即从返回结果中提取 agentId 并登记。

| 角色 | agentId | Phase | 状态 | 备注 |
|------|---------|-------|------|------|
| planner | a1b2c3d4 | 2 | ✅ 完成 | |
| designer | e5f6g7h8 | 3 | 🔄 修正中 | 第1轮修正 |
| design-reviewer | i9j0k1l2 | 4 | ✅ 完成 | |
| security-reviewer | m3n4o5p6 | 4 | ✅ 完成 | |
| performance-reviewer | q7r8s9t0 | 4 | ✅ 完成 | |
| req-completeness-reviewer | u1v2w3x4 | 4 | ✅ 完成 | |
| coder | y5z6a7b8 | 5 | 🔄 Batch 1 | R01-R03 |
| code-quality-reviewer | — | 6 | ⏳ 待启动 | |
| code-security-reviewer | — | 6 | ⏳ 待启动 | |
| code-req-reviewer | — | 6 | ⏳ 待启动 | |
| tester | — | 7 | ⏳ 待启动 | |

### 登记规则
1. 子Agent启动后，**立即**从返回结果提取 agentId 并更新此表
2. 修正循环 Resume 时，agentId 不变，更新状态和备注
3. 架构级回退重新创建子Agent时，记录新 agentId，旧行标记 `❌ 已废弃`
4. 全流程完成后，所有行状态应为 ✅ 或 ⚠️

## 时间线

- 260501 0930 项目启动
- 260501 0932 Phase 1 完成，共 {N} 条需求
- 260501 0935 Phase 2 planner 启动 → agentId: a1b2c3d4
- 260501 0940 Phase 2 完成
- 260501 0945 Phase 3 designer 启动 → agentId: e5f6g7h8
- 260501 0948 Phase 3 骨架确认
- 260501 0955 Phase 3 完成
- 260501 0957 Phase 4 启动 4 个评审:
    - design-reviewer → agentId: i9j0k1l2
    - security-reviewer → agentId: m3n4o5p6
    - performance-reviewer → agentId: q7r8s9t0
    - req-completeness-reviewer → agentId: u1v2w3x4
- 260501 1002 Phase 4 结果: C=0 H=1 M=2 L=1 覆盖=100% → FAIL
- 260501 1003 修正第1轮: SendMessage(to: e5f6g7h8) Resume designer
- 260501 1005 重新评审: SendMessage(to: i9j0k1l2, ...) C=0 H=0 覆盖=100% → PASS
- 260501 1007 ── Batch 1: R01-R03 ──
- 260501 1007 Phase 5 coder 启动 → agentId: y5z6a7b8
- 260501 1015 Phase 5 Batch 1 完成
- 260501 1016 Phase 6 启动 3 个 CR:
    - code-quality-reviewer → agentId: ...
    - code-security-reviewer → agentId: ...
    - code-req-reviewer → agentId: ...
- 260501 1020 Phase 6 结果: C=0 H=0 实现=100% → PASS
- 260501 1022 Phase 7 tester 启动 → agentId: ...
- 260501 1025 Phase 7: 12/12 passed, 覆盖 85%, 影响面已覆盖 → PASS
- 260501 1027 Phase 8 交付报告生成
- 260501 1028 全流程完成 ✅
```

## 日志规则

1. 每个 Phase 开始和结束都记录
2. 修正循环每轮记录
3. 子Agent只记启动和结果，不记中间过程
4. 统计缩写: C=CRITICAL H=HIGH M=MEDIUM L=LOW
5. 批次用分隔线: `── Batch N: R01-R03 ──`

## 子Agent log 文件

每个子Agent写独立文件，防止并行写入冲突：

| 子Agent | 文件 |
|---------|------|
| planner | `log/phase2-知识采集.md` |
| designer | `log/phase3-系分编写.md` |
| design-reviewer | `log/phase4-评审-架构.md` |
| security-reviewer | `log/phase4-评审-安全.md` |
| performance-reviewer | `log/phase4-评审-性能.md` |
| req-completeness-reviewer | `log/phase4-评审-需求完整度.md` |
| coder | `log/phase5-编码.md` |
| code-quality-reviewer | `log/phase6-CR-质量.md` |
| code-security-reviewer | `log/phase6-CR-安全.md` |
| code-req-reviewer | `log/phase6-CR-需求实现度.md` |
| tester | `log/phase7-测试.md` |
| 迭代修正 | `log/phase{N}-迭代-{轮次}.md` |

## 执行摘要

全流程完成后生成 `log/执行摘要.md`:

```markdown
# 执行摘要

| 阶段 | 日志文件 | 结果 |
|------|---------|------|
| Phase 1 需求澄清 | 需求清单.md | {N}条需求 |
| Phase 2 知识采集 | log/phase2-知识采集.md | 完成 |
| Phase 3 系分编写 | log/phase3-系分编写.md | 完成 |
| Phase 4 系分评审 | log/phase4-评审-*.md | PASS (第{N}轮) |
| Phase 5 编码实现 | log/phase5-编码.md | {N}条需求已编码 |
| Phase 6 代码CR | log/phase6-CR-*.md | PASS (第{N}轮) |
| Phase 7 测试验证 | log/phase7-测试.md | {N}/{M} passed |
| Phase 8 交付报告 | 交付报告.md | 完成率 XX% |
```
