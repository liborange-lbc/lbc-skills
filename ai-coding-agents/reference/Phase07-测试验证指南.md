# 测试验证指南

> tester 子Agent 在 Phase 7 使用。

## 输入

- 代码文件 + 测试文件
- `需求清单.md` — 逐条确认测试通过
- EXTENSION_DOCS.testing — 测试规范等
- GitNexus 索引 — 影响面分析

## 执行流程

### 1. 运行测试套件

```bash
{build_tool} test    # 运行全部测试
```

### 2. 检查覆盖率

目标: ≥ 80%。低于目标时列出未覆盖的关键路径。

### 3. 静态检查

```bash
# lint + typecheck（根据项目技术栈）
```

### 4. GitNexus 影响面分析

**关键步骤**: 用 GitNexus 检查本次变更的影响范围，确认测试覆盖所有受影响模块。

```bash
# 检测本次变更影响了哪些符号和执行流
gitnexus detect-changes --scope all --base-ref {base-branch} -r {project-name}

# 对关键变更符号做上游影响分析
gitnexus impact {ChangedSymbol} --direction upstream --depth 3 --include-tests -r {project-name}
```

**核对规则**:
- detect-changes 列出的每个受影响执行流，必须有对应测试覆盖
- impact 分析中的上游依赖方，如果没有测试覆盖，标记为 **HIGH** 风险
- 将影响面分析结果写入测试报告的"影响面覆盖"章节

### 5. 需求级验证

逐条需求确认至少有一个 PASS 的测试：

| 需求ID | 描述 | 对应测试 | 结果 |
|--------|------|---------|------|
| R01 | ... | test_xxx | ✅ PASS |

## 产出格式

写入 `log/phase7-测试.md`:

```markdown
# 测试验证报告

## 测试结果
- 单元测试: N passed / M total
- 覆盖率: XX%
- Lint: PASS/FAIL
- TypeCheck: PASS/FAIL

## 影响面覆盖
- GitNexus detect-changes 发现 N 个受影响执行流
- 已测试覆盖: N 个
- 未覆盖风险项:
  | 受影响符号 | 上游依赖方 | 风险等级 |
  |-----------|-----------|---------|

## 需求级测试覆盖
| 需求ID | 描述 | 测试 | 结果 |
|--------|------|------|------|

## 失败项
| 测试名 | 失败原因 | 关联需求 |
|--------|---------|---------|

## 判定
### 判定：PASS / FAIL
```

## 测试不通过处理

- 测试失败 → 主Agent Resume coder 修复 → 重新运行测试
- 影响面未覆盖 → 主Agent Resume coder 补充测试
- 最多 MAX_ITERATION 轮
