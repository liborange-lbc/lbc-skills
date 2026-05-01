---
name: ai-coding-agents
description: >-
  全流程编码流水线：需求澄清 → 系分编写 → 系分评审 → 编码实现 → 代码CR → 测试验证 → 交付报告。
  多智能体协同，需求完整度贯穿追踪，闭环迭代，扩展文档挂载。
  Use when user asks to 帮我实现, 开发这个功能, implement this feature, or ai-coding.
---

# AI Coding Agents — 全流程编码流水线

## Trigger

- 帮我实现 / 开发这个功能 / 帮我写 / implement / ai-coding
- 从需求到交付 / 全流程开发

## Configuration

> 首次使用前填写。EXTENSION_DOCS 未配置项留空不影响核心流程。

```yaml
# === 项目基础 ===
PROJECT_ROOT: "."
OUTPUT_DIR: ".ai-coding"
TECH_STACK:
  language: "{{language}}"               # Java | TypeScript | Python | Go | ...
  framework: "{{framework}}"            # Spring Boot | Next.js | FastAPI | ...
  test_framework: "{{test_framework}}"   # JUnit | Jest | Pytest | ...
  build_tool: "{{build_tool}}"           # Maven | npm | pip | ...
  architecture: "{{architecture}}"       # microservice | monolith | modular-monolith

# === 扩展文档挂载 ===
# type: feishu | confluence | local | git | url
# 每个阶段可挂载多份文档，启动对应角色时自动注入。
EXTENSION_DOCS:
  requirement: []     # 产品PRD、业务流程图 → planner
  design: []          # 业务知识文档、数据字典、API契约 → designer
  coding: []          # 代码军规、编码规范、框架使用指南 → coder
  review: []          # 评审检查清单、安全基线 → reviewer
  testing: []         # 测试规范、E2E场景库 → tester
  # 示例:
  # coding:
  #   - name: "代码军规"
  #     path: "/docs/coding-rules.md"
  #     type: "local"

# === 流程控制 ===
BATCH_SIZE: 1                            # 每批实现的需求条目数
MAX_ITERATION: 3                         # 评审/CR 最大迭代轮数
DESIGN_TEMPLATE_URL: ""                  # 系分模板地址，空则用内置模板
```

---

## 主Agent行为准则

1. **纯调度不执行** — 绝不直接编辑代码文件，绝不直接读子Agent产出内容
2. **Grep提取判定** — 只用 Grep 提取评审报告的 PASS/FAIL + 统计行
3. **Task驱动** — 每个 Phase 开始前 TaskCreate，完成后 TaskUpdate
4. **日志记录** — 所有关键事件写入 `{需求目录}/log/执行日志.md`
5. **扩展文档转发** — 启动子Agent时将 EXTENSION_DOCS 对应路径注入 prompt
7. **AgentID管理** — 记录每个子Agent的ID，修正循环时用 SendMessage Resume

### Agent 生命周期管理

```
首次启动子Agent:
  result = Agent(prompt: "...", subagent_type: "...")
  → 从返回结果中提取 agentId
  → 记录到执行日志: "designer agentId: abc123"

修正循环中 Resume 同一子Agent:
  SendMessage(to: "{agentId}", message: "根据评审报告修复以下问题: ...")
  → 子Agent保留完整对话历史，理解原始设计意图
  → 无需重新传入系分文档/代码（已在上下文中）

Resume vs 新建的选择:
  ● 修正循环（局部问题）→ SendMessage Resume（保留上下文）
  ● 回退重做（架构级问题）→ 新建 Agent（全新上下文）
  ● 跨Phase切换 → 新建 Agent（不同角色）

AgentID 注册表:
  所有 agentId 登记到执行日志的 "Agent 注册表" 章节
  → 详见 [reference/执行日志规范.md](reference/执行日志规范.md)
```

### 并行Agent执行

Phase 4（4个评审）和 Phase 6（3个CR）用 `Agent(run_in_background: true)` 并行启动：
```
1. 并行启动多个子Agent，每个子Agent内部用 TaskCreate/TaskUpdate 汇报进度
2. 主Agent收到完成通知后，Grep 提取判定结果
3. 用户通过 Task 列表查看所有Agent的实时状态
```

---

## Workflow

```
P1 需求澄清 → P2 知识采集 → P3 系分编写 → P4 系分评审 ⇄ 修正(≤3轮)
interviewer    planner       designer      3×reviewer    Resume designer
                                                ↓ PASS
                                           P5 编码实现 → P6 代码CR ⇄ 修正(≤3轮)
                                             coder       3×reviewer  Resume coder
                                                              ↓ PASS
                                                         P7 测试验证 → P8 交付报告
                                                           tester      主Agent

门禁: P4/P6 必须 0 CRITICAL + 0 HIGH + 需求覆盖/实现 100% 才 PASS
快捷: 有需求文档→P2 | 有系分→P4 | 有代码→P6
主线: 需求清单.md 贯穿全程 | 经验库.md 跨需求复用
```


---

## Phase 1: 需求澄清

**执行者**: interviewer 子Agent  
**产出**: `{需求目录}/需求清单.md`

1. 按面试清单逐项确认（用 AskUserQuestion 与用户对话）
2. 拆解为**原子级需求条目**（每条可独立验收、可独立测试）
3. 产出需求清单，主Agent转交用户确认后才进 Phase 2

详细清单 → [subagent/phase01-需求访谈员/需求面试清单.md](subagent/phase01-需求访谈员/需求面试清单.md)

---

## Phase 2: 知识采集

**执行者**: planner 子Agent  
**挂载**: EXTENSION_DOCS.requirement  
**产出**: `代码阅读报告.md` + `知识摘要.md`

1. **GitNexus 索引** — 对项目执行 `gitnexus analyze`，建立知识图谱
2. **代码下钻** — 六步下钻法 + GitNexus context/query 双路并行
3. **知识库查阅** — 按优先级读取文档，冲突时以代码为准

详细指南 → [subagent/phase02-知识采集员/代码阅读指南.md](subagent/phase02-知识采集员/代码阅读指南.md) + [subagent/phase02-知识采集员/知识查阅规则.md](subagent/phase02-知识采集员/知识查阅规则.md)

---

## Phase 3: 系分编写

**执行者**: designer 子Agent  
**挂载**: EXTENSION_DOCS.design  
**产出**: `系分文档.md` + `需求追踪矩阵.md`

1. **先出骨架** — 章节标题让用户确认
2. **需求-设计映射** — 每条需求对应设计章节、接口、数据变更
3. **填充内容** — 遵循架构约束
4. **保存文档**

架构约束 → [subagent/phase03-系分设计师/架构约束.md](subagent/phase03-系分设计师/架构约束.md)  
文档模板 → [subagent/phase03-系分设计师/设计文档模板.md](subagent/phase03-系分设计师/设计文档模板.md)

---

## Phase 4: 系分评审

**执行者**: 3个并行 reviewer 子Agent  
**挂载**: EXTENSION_DOCS.review

| Agent | 视角 | 详细checklist |
|-------|------|--------------|
| design-reviewer | 架构合理性 | [reference/评审检查清单.md](reference/评审检查清单.md) §系分-架构 |
| performance-reviewer | 性能容量 | 同上 §系分-性能 |
| **req-completeness-reviewer** | **需求完整度** | 同上 §需求完整度 — 逐条核对R01-RNN |

**Pass Criteria**: 0 CRITICAL + 0 HIGH + 需求覆盖100%  
**FAIL**: → 修正循环，Resume designer → Resume reviewers，≤ MAX_ITERATION 轮

修正协议 → [reference/修正循环协议.md](reference/修正循环协议.md)

---

## Phase 5: 编码实现

**执行者**: coder 子Agent（可 Resume）  
**挂载**: EXTENSION_DOCS.coding

按 BATCH_SIZE 分批实现，每条需求对应至少一个测试。

详细指南 → [subagent/phase05-编码工程师/编码实现指南.md](subagent/phase05-编码工程师/编码实现指南.md)

---

## Phase 6: 代码 CR

**执行者**: 3个并行 reviewer 子Agent  
**挂载**: EXTENSION_DOCS.review + EXTENSION_DOCS.coding

| Agent | 视角 | 详细checklist |
|-------|------|--------------|
| code-quality-reviewer | 代码质量 | [reference/评审检查清单.md](reference/评审检查清单.md) §代码-质量 |
| code-security-reviewer | 安全漏洞 | 同上 §代码-安全 |
| **code-req-reviewer** | **需求实现完整度** | 同上 §需求实现度 — 逐条在代码中验证 |

**Pass Criteria**: 0 CRITICAL + 0 HIGH + 需求实现100%  
**FAIL**: → Resume coder 修复 → Resume reviewers，≤ MAX_ITERATION 轮

---

## Phase 7: 测试验证

**执行者**: tester 子Agent  
**挂载**: EXTENSION_DOCS.testing

1. 运行测试 + lint + typecheck
2. **GitNexus 影响面分析** — `gitnexus detect-changes` 检查变更影响范围，确认测试覆盖所有受影响模块
3. 逐条需求确认测试通过

详细指南 → [subagent/phase07-测试工程师/测试验证指南.md](subagent/phase07-测试工程师/测试验证指南.md)

---

## Phase 8: 交付报告

**执行者**: 主Agent  
**产出**: `交付报告.md`

汇总需求完成率、产出物清单、变更文件、残留风险、commit message 建议。

模板 → [reference/交付报告模板.md](reference/交付报告模板.md)

---

## 产出目录结构 — 按需求隔离

每个需求独立目录，互不干扰：

```
{PROJECT_ROOT}/{OUTPUT_DIR}/
├── 经验库.md                              # 全局共享，跨需求累积
├── {需求名称}/                             # 每个需求独立目录
│   ├── 需求清单.md                         # Phase 1 产出（带全生命周期状态）
│   ├── 代码阅读报告.md                     # Phase 2 产出
│   ├── 知识摘要.md                         # Phase 2 产出
│   ├── 系分文档.md                         # Phase 3 产出
│   ├── 需求追踪矩阵.md                     # Phase 3 产出
│   ├── 交付报告.md                         # Phase 8 产出
│   └── log/                               # 执行日志（子Agent独立写入，防冲突）
│       ├── 执行日志.md                     # 主Agent时间线
│       ├── phase2-知识采集.md
│       ├── phase3-系分编写.md
│       ├── phase4-评审-架构.md              # 子Agent独立文件
│       ├── phase4-评审-安全.md
│       ├── phase4-评审-性能.md
│       ├── phase4-评审-需求完整度.md
│       ├── phase4-迭代-1.md                 # 迭代按编号追加
│       ├── phase5-编码.md
│       ├── phase6-CR-质量.md
│       ├── phase6-CR-安全.md
│       ├── phase6-CR-需求实现度.md
│       ├── phase6-迭代-1.md
│       ├── phase7-测试.md
│       └── 执行摘要.md                     # 全局索引（链接所有log文件）
```

### 需求状态生命周期

| 状态 | 含义 | 阶段 |
|------|------|------|
| ⏳ | 待处理 | 初始 |
| 📐 | 已设计 | Phase 3 |
| 💻 | 已编码 | Phase 5 |
| ✅ | 已验证 | Phase 7 |
| ⚠️ | 低质量通过 | 3轮修正后仍有问题 |

---

## 上下文隔离

| 角色 | 读取 | 不读 |
|------|------|------|
| 主Agent | 文件路径 + Grep判定 | 代码、系分全文、评审全文 |
| interviewer | 用户对话、EXTENSION_DOCS.requirement | 代码文件 |
| planner | 需求清单、代码库、GitNexus索引 | 其他Agent产出 |
| designer | 需求清单、代码阅读报告、知识摘要 | 代码文件 |
| coder | 系分文档、追踪矩阵、经验库 | 评审报告全文 |
| reviewer-* | 系分/代码、需求清单、追踪矩阵 | 其他reviewer的报告 |
| tester | 代码、测试文件、GitNexus影响面 | 系分文档 |

---

## Task 防遗忘

每个 Phase 创建 Task，每条需求在编码阶段也创建独立 Task：

```
TaskCreate: "Phase 1 — 需求澄清"
TaskCreate: "Phase 3 — 系分编写"
TaskCreate: "Phase 5 Batch 1 — R01 手机号注册"
TaskCreate: "Phase 5 Batch 1 — R02 唯一性校验"
TaskCreate: "Phase 6 — 代码CR"
TaskCreate: "Phase 7 — 测试验证"
```

完成一个，TaskUpdate 一个。绝不批量延迟标记。

---

## 文档质量总则

全流程以文档驱动，每个Phase的产出文档是下游Phase的Input。文档质量直接决定流水线成败。

### 通用质量要求（所有产出文档）

1. **无空章节** — 每个章节必须有实质内容，不允许"TODO"或"待补充"
2. **来源标注** — 引用代码标注 `[来源: 文件:行号]`，引用文档标注 `[来源: 文档名, 章节]`
3. **不得编造** — 查不到的信息写"未找到"，不得凭想象填写
4. **格式规范** — 严格按各执行指南中定义的产出格式
5. **判定行首行** — 评审报告第一行必须是 `## 判定：PASS` 或 `## 判定：FAIL`

### 各Phase产出物一览

| Phase | 产出文件 | 质量关键指标 | 下游消费者 |
|-------|---------|-------------|-----------|
| P1 | 需求清单.md | 每条需求有验收标准、无"待定" | P2 planner, P3 designer, P4/P6 reviewer |
| P2 | 代码阅读报告.md + 知识摘要.md | 来源标注、风险覆盖 | P3 designer |
| P3 | 系分文档.md + 需求追踪矩阵.md | 需求覆盖100%、架构约束通过 | P4 reviewer, P5 coder |
| P4 | log/phase4-评审-*.md | 判定行首行、问题有具体建议 | 主Agent判定、designer修正 |
| P5 | 代码 + 测试 + log/phase5-编码.md | 每条需求有代码+测试 | P6 reviewer, P7 tester |
| P6 | log/phase6-CR-*.md | 判定行首行、问题有文件:行号 | 主Agent判定、coder修正 |
| P7 | log/phase7-测试.md | 测试通过率、影响面覆盖 | 主Agent、P8 交付报告 |
| P8 | 交付报告.md | 需求完成率、残留风险 | 用户 |

### 经验库规范

→ [reference/经验库规范.md](reference/经验库规范.md)

---

## 设计原则

1. **主Agent纯调度** — 不执行、只决策和路由
2. **需求驱动全流程** — 需求清单贯穿 8 个 Phase
3. **文档驱动交接** — Phase间通过文档传递，文档质量=流水线质量
4. **Resume优于新建** — 修正循环用 SendMessage(to: agentId) 复用同一Agent
5. **经验库累积** — 修正中沉淀的模式跨需求复用
6. **按需求隔离** — 不同需求独立目录，互不干扰
7. **GitNexus赋能** — 代码分析用知识图谱，测试用影响面分析
8. **扩展优于硬编码** — EXTENSION_DOCS 挂载外部知识
