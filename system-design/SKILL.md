---
name: system-design
description: >-
  Generate and review system design documents (系统设计/系分) for Java projects.
  Use when user asks to create system design, 写系分, 系统设计, 技术方案, or review
  an existing design doc. Closed-loop workflow with multi-agent review.
  Auto-generates system knowledge base and logs full execution trace.
---

# System Design — 系分生成与评审

## Mindset — 执行态度（贯穿全流程）

> 以下原则约束本 skill 每一个阶段的行为。违背任何一条，产出质量不可信。

1. **先想再动** — 不假设、不隐藏困惑。遇到多种理解时摆出来让用户选，而非默默挑一个。不确定就停下来问。
2. **最小方案** — 只解决被要求的问题。不加未被要求的功能、抽象、"灵活性"。50 行能解决的不写 200 行。
3. **精确手术** — 只改必须改的部分。不顺手"优化"相邻代码，不改不相关的格式，不加没必要的注释。每一处改动都能直接追溯到需求。
4. **目标驱动** — 每个阶段都有明确的完成标准。写完不算完，验证通过才算完。
5. **敢于质疑** — 服务于目标，不盲从指令。如果需求有逻辑漏洞、隐含风险或更好的替代方案，先说出来再执行。沉默的服从是负债。
6. **最小修复** — 迭代遇到问题时，先定位到具体的点，只改那一处。不默认全量重写。升级路径：局部修复 → 结构重做 → 全量重启，逐级才升级。
7. **上下文节制** — 用 subagent 做重活（代码阅读、评审），主流程只处理决策和协调。宝贵的上下文窗口留给判断，不浪费在搬运上。

---

## Trigger

- 写系分 / 系统设计 / 技术方案 / 详细设计
- 帮我评审系分 / review this design

## Configuration

> 零配置即可运行。TECH_STACK 由 Phase 0 自动识别；如需覆盖或补充外部知识源，可手动填写。

```yaml
# ── 自动识别（Phase 0 从代码推断，通常无需手动填写）──
TECH_STACK:
  language: "Java"              # 自动识别
  framework: "Spring Boot"      # 自动识别
  orm: "MyBatis"                # 自动识别
  middleware: []                # 自动识别: Redis, RocketMQ, Kafka, ES, etc.
  database: "MySQL"             # 自动识别
  architecture: "microservice"  # 自动识别: monolith | microservice | modular-monolith

# ── 可选：外部知识源（有则查阅，无则完全依赖代码）──
TEMPLATE_URL: ""                # 系分模板 URL，留空则使用内置模板
KNOWLEDGE_BASES: []             # 外部文档源，格式如下：
  # - name: "系分文档库"
  #   url: "https://..."
  #   type: "yuque"            # yuque | confluence | local | git
```

---

## Directory Structure

所有产出存放在项目根目录下的 `./ai-coding-doc/`：

```
./ai-coding-doc/
├── system-knowledge/                    # 系统知识目录（全局，跨需求共享）
│   ├── architecture-overview.md         #   架构总览（分层、模块、部署拓扑）
│   ├── middleware-inventory.md          #   中间件明细（Redis/MQ/ES 等用法）
│   ├── api-constraints.md              #   API 约束（命名、版本、鉴权、限流规范）
│   ├── domain-model.md                 #   领域模型（核心实体、聚合根、关系图）
│   ├── coding-conventions.md           #   编码规范（异常处理、日志、分层调用规则）
│   ├── data-dictionary.md              #   数据字典（核心表结构、索引、枚举值）
│   └── infra-config.md                 #   基础设施配置（环境、配置中心、部署方式）
│
├── biz-knowledge/                       # 业务知识目录（人工维护）
│   ├── biz-map.md                       #   【必须】业务知识导引（文档链接+使用说明）
│   └── *.md                             #   业务知识文档（按主题组织）
│
├── requirements/                        # 需求迭代目录（按需求独立保存）
│   └── {YYYY-MM-DD}-{feature-name}/    #   每个需求一个目录
│       ├── requirement-checklist.md     #     需求确认清单
│       ├── code-reading-report.md       #     代码阅读报告
│       ├── design-doc.md               #     系分文档
│       ├── review-report.md            #     评审报告
│       └── log/                         #     执行日志目录
│           ├── phase0-knowledge-bootstrap.md
│           ├── phase1-requirement-interview.md
│           ├── phase2a-code-reading.md
│           ├── phase2b-knowledge-lookup.md
│           ├── phase3-design.md
│           ├── phase4-agent-{role}.md   #     每个评审 Agent 独立文件
│           ├── phase5-iteration-{n}.md
│           ├── execution-summary.md     #     执行路径汇总
│           └── execution-flowchart.md   #     全局流程图（Mermaid）
│
└── reference/                           # 参考文档（模板、checklist 等）
    ├── design-template.md               #   系分文档模板
    ├── requirement-checklist.md         #   需求面试清单
    ├── review-checklists.md             #   评审 checklist
    ├── code-reading-guide.md            #   六步下钻法指南
    └── knowledge-lookup-rules.md        #   知识库查阅规则
```

### 初始化

首次运行时自动创建目录结构。`reference/` 下的模板文件从 skill 的 `reference/` 目录复制过去。

---

## Navigation Map — 文档导引

> 所有路径均为相对于 `./ai-coding-doc/` 的相对路径，skill 可跨项目复用。

| 场景 | 该看什么 | 路径 |
|------|----------|------|
| 了解系统全貌 | 架构总览 | `system-knowledge/architecture-overview.md` |
| 确认中间件用法 | 中间件明细 | `system-knowledge/middleware-inventory.md` |
| 设计新 API 前 | API 约束 | `system-knowledge/api-constraints.md` |
| 理解数据模型 | 领域模型 | `system-knowledge/domain-model.md` |
| 确认编码规范 | 编码规范 | `system-knowledge/coding-conventions.md` |
| 查表结构/字段 | 数据字典 | `system-knowledge/data-dictionary.md` |
| 查环境/部署配置 | 基础设施配置 | `system-knowledge/infra-config.md` |
| 了解业务背景/规则 | 业务知识导引 | `biz-knowledge/biz-map.md` |
| 写系分文档 | 文档模板 | `reference/design-template.md` |
| 面试需求 | 面试清单 | `reference/requirement-checklist.md` |
| 评审系分 | 评审 checklist | `reference/review-checklists.md` |
| 阅读代码 | 六步下钻法 | `reference/code-reading-guide.md` |
| 查阅知识库 | 查阅规则 | `reference/knowledge-lookup-rules.md` |
| 查历史需求 | 需求目录 | `requirements/` |
| 查执行过程 | 执行日志 | `requirements/{date}-{name}/log/` |

---

## Workflow Overview

```
Phase 0 系统知识检查/生成
  → Phase 1 需求面试
  → Phase 2 知识采集
  → Phase 3 方案设计
  → Phase 4 多Agent评审
  → [不通过] → Phase 5 分级修正 → Phase 4 再评审（最多 3 轮）
  → [通过: 0 CRITICAL + 0 HIGH] → Phase 6 日志汇总 → Done
```

如果用户已有系分文档只需评审：**直接跳到 Phase 4**（但仍先执行 Phase 0 确保系统知识完备）。

---

## Execution Logging（贯穿全流程）

**每个 Phase 都必须写入执行日志**。日志是系分过程的可追溯记录。

详细规范 → [reference/execution-logging-guide.md](reference/execution-logging-guide.md)

### 日志格式

每个日志文件使用统一格式：

```markdown
# Phase N: {阶段名称}

> 开始时间: {timestamp}
> 结束时间: {timestamp}
> 状态: 进行中 | 完成 | 跳过

## Step N.1: {步骤名称}

**决策点**: {为什么执行这一步 / 判断依据}
**执行动作**: {具体做了什么}
**引用材料**:
- 文档: `{relative-path}` — {引用了什么内容}
- 代码: `{file:line}` — {读取了什么}
- 链接: {URL} — {获取了什么}
**结论**: {得到了什么结果 / 产出了什么}

---
```

### Subagent 日志

每个 subagent 写入独立文件。文件名含角色标识（如 `phase4-agent-architect.md`）。Subagent 启动时将自身的 prompt 摘要、执行步骤、引用材料、发现结论全部写入对应日志文件。

### 主流程日志转发

主流程负责在每个 Phase 开始/结束时追加记录到对应日志文件。Subagent 返回后，主流程在自己的日志中记录 subagent 的关键结论和产出路径。

---

## Phase 0: System Knowledge Bootstrap

**目标**：确保系统知识目录完整、准确，为后续设计提供全局上下文。

### 执行流程

1. **检查 `./ai-coding-doc/system-knowledge/` 目录**
   - 不存在 → 创建目录，执行全量生成
   - 存在但文件不全 → 补充缺失文件
   - 存在且完整 → 抽样校验（读取 2-3 个文件，与当前代码对比），过时则更新

2. **全量/增量生成**

   启动 subagent 按六步下钻法阅读整个项目代码，产出以下 7 个文件：

   | 文件 | 内容 | 六步下钻对应 |
   |------|------|-------------|
   | `architecture-overview.md` | 分层架构、模块划分、服务拓扑、部署方式 | Step 1 + Step 6 |
   | `middleware-inventory.md` | 每个中间件的用途、配置、key 设计、使用模式 | Step 5 |
   | `api-constraints.md` | URL 命名规范、版本策略、鉴权方式、限流规则、错误码体系 | Step 1 |
   | `domain-model.md` | 核心实体/聚合根/值对象、ER 关系图、枚举定义 | Step 2 |
   | `coding-conventions.md` | 异常处理、日志规范、分层调用规则、命名约定 | Step 3 + 全局 |
   | `data-dictionary.md` | 核心表结构、字段说明、索引、数据量级 | Step 4 |
   | `infra-config.md` | 环境配置、配置中心、feature flag、CI/CD 流程 | Step 6 |

   六步下钻法详细指南 → [reference/code-reading-guide.md](reference/code-reading-guide.md)

3. **生成完成后**，在日志中记录每个文件的生成/跳过/更新状态

4. **加载业务知识导引**

   检查 `./ai-coding-doc/biz-knowledge/biz-map.md` 是否存在：

   | 情况 | 处理 |
   |------|------|
   | 文件存在 | **读取全部内容**，加载到当前上下文，作为后续 Phase 1~5 的业务背景。日志中记录"已加载 biz-map.md，包含 N 个业务知识条目" |
   | 目录存在但缺少 biz-map.md | 提示用户：`biz-knowledge/ 目录已存在但缺少 biz-map.md 导引文件，请按模板创建后重新运行，或输入"跳过"继续（将仅依赖代码和系统知识）` |
   | 目录不存在 | 提示用户：`未发现 ./ai-coding-doc/biz-knowledge/ 目录。如果有业务知识文档（PRD、业务规则、流程说明等），建议创建该目录并添加 biz-map.md 导引文件。输入"跳过"可继续，后续设计将仅依赖代码和系统知识` |

   **biz-map.md 模板**（提示用户时附带）：

   ```markdown
   # 业务知识导引

   > 本文件是业务知识的索引入口。列出所有业务知识文档及其使用场景。
   > 文档放在 biz-knowledge/ 目录下，此处用相对路径引用。

   | 文档 | 内容概要 | 适用场景 |
   |------|----------|----------|
   | [交易流程.md](交易流程.md) | 下单→支付→履约全流程 | 涉及交易链路的需求设计 |
   | [权限模型.md](权限模型.md) | RBAC 角色与权限矩阵 | 涉及鉴权、数据隔离的设计 |
   | [结算规则.md](结算规则.md) | T+1 结算、分账、退款规则 | 涉及资金流的需求设计 |

   ## 外部文档链接

   | 名称 | 链接 | 说明 |
   |------|------|------|
   | PRD 文档库 | {飞书/Confluence URL} | 产品需求文档 |
   | 业务流程图 | {URL} | 核心业务流程 |
   ```

### 日志输出

写入 `log/phase0-knowledge-bootstrap.md`，记录：
- 哪些知识文件已存在、哪些需要生成/更新
- 每个文件的生成过程（读了哪些代码、得出什么结论）
- biz-map.md 加载状态（已加载/用户跳过/不存在）
- 最终状态：7 个系统知识文件全部就绪 + 业务知识加载情况

---

## Phase 1: 需求面试

**目标**：消除歧义。不清楚就不动手。

用 AskUserQuestion 逐项确认，直到需求无歧义。产出**需求确认清单**，用户签字后才进 Phase 2。

详细清单 → [reference/requirement-checklist.md](reference/requirement-checklist.md)

### 日志输出

写入 `log/phase1-requirement-interview.md`，记录：
- 每轮提问内容和用户回答
- 歧义点及其澄清过程
- 最终确认的需求清单

---

## Phase 2: 知识采集

**目标**：建立设计所需的全部上下文。

> **CRITICAL: 采集完成前禁止开始设计。这是准确性的根基。**

### 2a. 代码阅读

用 subagent 按六步下钻法阅读**本次需求涉及**的模块代码（Phase 0 是全局，这里是聚焦），产出**代码阅读报告**（依赖图、调用链、现有约束、数据模型、风险标记）。

详细步骤 → [reference/code-reading-guide.md](reference/code-reading-guide.md)

**与 Phase 0 的区别**：Phase 0 生成全局系统知识，Phase 2a 聚焦本次需求涉及的具体模块，深度更大、范围更窄。Phase 2a 可引用 Phase 0 的产出作为上下文。

### 2b. 知识库查阅

按优先级查阅：已有系分 → API 契约 → 数据字典 → 业务流程文档。

**三条硬性规则**：
1. 所有引用必须标注来源（文档名+章节 或 文件路径+行号）
2. 文档与代码冲突时，**以代码为准**，标记差异
3. 查不到时明确写出"未找到相关文档，以代码为准"，**不得编造**

详细规则 → [reference/knowledge-lookup-rules.md](reference/knowledge-lookup-rules.md)

### 2c. 模板获取

从 TEMPLATE_URL 拉取系分模板。不可用时使用 `reference/design-template.md`。

### 日志输出

- `log/phase2a-code-reading.md` — 代码阅读 subagent 的完整执行过程
- `log/phase2b-knowledge-lookup.md` — 知识库查阅过程、每条引用的来源

---

## Phase 3: 方案设计

**目标**：生成结构化、可评审的系分文档。

### 流程

1. **先出骨架** — 只有章节标题，让用户确认再填充
2. **填充内容** — 严格遵循下方架构约束，引用 `system-knowledge/` 中的全局上下文
3. **保存文档** — 输出到 `./ai-coding-doc/requirements/{date}-{feature-name}/design-doc.md`

文档模板与格式 → [reference/design-template.md](reference/design-template.md)

### Architecture Constraints（不遵循必出问题）

**MUST — 每条都要在设计中体现，缺一项评审必不过：**

| # | 约束 | 为什么 |
|---|------|--------|
| 1 | 所有写接口必须说明幂等机制 | 网络重试、MQ 重复消费都会导致重复写入 |
| 2 | 新接口字段只增不删不改类型 | 破坏向前兼容会导致已上线调用方报错 |
| 3 | 外部依赖必须有降级/熔断策略 | 下游故障会级联拖垮上游 |
| 4 | 新接口必须说明鉴权方案 | 裸露接口 = 安全事故 |
| 5 | @Transactional 范围尽可能小 | 大事务锁表、拖慢响应、阻塞连接池 |
| 6 | 关键路径必须有日志/指标/告警 | 线上问题不可观测 = 无法排查 |

**MUST NOT — 出现任何一条评审直接 CRITICAL：**

| # | 禁止 | 后果 |
|---|------|------|
| 1 | 事务内调用外部服务（RPC/HTTP/MQ） | 事务挂起等外部响应，连接池耗尽 |
| 2 | 单事务涉及 > 3 张表且无理由 | 锁范围过大，死锁概率剧增 |
| 3 | SELECT * 或无 LIMIT 查询 | 全表扫描或内存溢出 |
| 4 | 硬编码配置值 | 环境切换时必出问题 |
| 5 | 跨模块直接访问对方数据库表 | 模块耦合，无法独立演进 |

### 日志输出

写入 `log/phase3-design.md`，记录：
- 骨架确认过程（用户反馈）
- 每个章节填充时引用了哪些 system-knowledge 文件和代码
- 架构约束逐项检查结果

---

## Phase 4: 多 Agent 评审

**目标**：从 5 个视角并行发现设计缺陷。

### 执行方式

启动 **5 个并行 subagent**，每个读取完整系分文档 + 代码阅读报告 + 相关 system-knowledge 文件，按各自视角独立评审。

| Agent | 视角 | 核心关注 | 日志文件 |
|-------|------|----------|----------|
| 架构师 | 结构合理性 | 分层、耦合、扩展性、接口粒度、是否过度设计 | `log/phase4-agent-architect.md` |
| 安全专家 | 安全漏洞 | 鉴权、注入、越权、脱敏、日志泄露 | `log/phase4-agent-security.md` |
| 性能工程师 | 性能容量 | 索引、N+1、缓存策略、锁竞争、容量预估 | `log/phase4-agent-performance.md` |
| 业务分析师 | 业务完整性 | 需求覆盖、边界场景、状态机、异常流程 | `log/phase4-agent-business.md` |
| 代码考古学家 | 兼容性 | 接口契约、数据迁移、发布顺序、回滚方案 | `log/phase4-agent-archaeologist.md` |

各 Agent 详细 checklist → [reference/review-checklists.md](reference/review-checklists.md)

### 每个 Agent 的日志必须包含

1. **Agent 视角声明** — 我是谁、我关注什么
2. **Checklist 逐项检查** — 每个检查项的执行点、引用了设计文档哪个章节、代码哪个文件
3. **发现列表** — 每个问题的严重级别、位置、描述、修改建议
4. **结论** — 通过/不通过，问题统计

### 汇总规则

1. 收集所有 Agent 的发现
2. 去重合并（同一问题不同角度提到的算一条）
3. 按严重度排序：CRITICAL → HIGH → MEDIUM → LOW
4. 生成评审报告，保存到 `requirements/{date}-{feature-name}/review-report.md`

### Pass Criteria（硬性门禁）

| 条件 | 结果 |
|------|------|
| 0 CRITICAL **且** 0 HIGH | **PASS** — 评审通过 |
| 存在 CRITICAL 或 HIGH | **FAIL** — 进入 Phase 5 |

---

## Phase 5: 迭代修正

1. 展示评审报告给用户
2. **判定问题级别，决定回退深度**：

| 问题性质 | 判定标准 | 回退到 |
|----------|----------|--------|
| 局部问题 | 问题集中在具体章节，不影响整体架构 | 定点修改文档相关章节 → Phase 4 |
| 架构级问题 | 分层/边界/核心流程有根本性缺陷 | Phase 3 重新设计 → Phase 4 |
| 需求理解错误 | 设计方向与业务目标偏离 | Phase 1 重新面试 → 全流程 |

3. 对每个 CRITICAL/HIGH 问题生成**具体修改建议**（改哪里、改成什么）
4. 问用户："是否按建议修改？是否需要调整回退深度？"
5. 执行修改，重新跑 **Phase 4 评审**
6. 最多 **3 轮**。3 轮后仍有问题，列出残留项让用户决定

### 日志输出

每轮迭代写入 `log/phase5-iteration-{n}.md`，记录：
- 本轮修正的问题列表（来自哪个 Agent 的哪条发现）
- 回退深度判定理由
- 具体修改内容（改了设计文档的哪个章节、改了什么）
- 用户确认过程
- 修正后的重新评审结果摘要

---

## Phase 6: 日志汇总与流程图

**目标**：将分散在各文件的执行日志汇总为可视化的执行路径。

### 6a. 执行路径汇总

生成 `log/execution-summary.md`，格式：

```markdown
# 系分执行路径汇总

> 需求: {feature-name}
> 总耗时: Phase 0 开始 → Phase 5/6 结束
> 迭代轮数: N

## 执行时间线

| 阶段 | 状态 | 关键产出 | 详细日志 |
|------|------|----------|----------|
| Phase 0: 系统知识检查 | 完成 | 7 文件就绪 | [→ 详情](phase0-knowledge-bootstrap.md) |
| Phase 1: 需求面试 | 完成 | 需求确认清单 | [→ 详情](phase1-requirement-interview.md) |
| Phase 2a: 代码阅读 | 完成 | 代码阅读报告 | [→ 详情](phase2a-code-reading.md) |
| Phase 2b: 知识查阅 | 完成 | N 条引用 | [→ 详情](phase2b-knowledge-lookup.md) |
| Phase 3: 方案设计 | 完成 | 系分文档 | [→ 详情](phase3-design.md) |
| Phase 4: 多Agent评审 (R1) | FAIL | 2C/3H/5M | [架构师](phase4-agent-architect.md) [安全](phase4-agent-security.md) ... |
| Phase 5: 迭代修正 (R1) | 完成 | 修复 2C+3H | [→ 详情](phase5-iteration-1.md) |
| Phase 4: 多Agent评审 (R2) | PASS | 0C/0H/3M | [架构师](phase4-agent-architect.md) [安全](phase4-agent-security.md) ... |
| Phase 6: 日志汇总 | 完成 | 本文件 | — |

## 关键决策点

1. **Phase 0**: {决策描述} — {理由}
2. **Phase 3**: {骨架调整} — {用户反馈}
3. **Phase 5**: {回退深度选择} — {判定理由}
```

### 6b. 全局执行流程图

生成 `log/execution-flowchart.md`，使用 Mermaid flowchart 语法：

```markdown
# 执行流程图

\`\`\`mermaid
flowchart TD
    Start([开始]) --> P0[Phase 0: 系统知识检查]
    P0 -->|知识完备| P0_OK[7 文件就绪]
    P0 -->|知识缺失| P0_GEN[六步下钻生成]
    P0_GEN --> P0_OK

    P0_OK --> P1[Phase 1: 需求面试]
    P1 -->|N轮问答| P1_OK[需求确认清单]

    P1_OK --> P2A[Phase 2a: 代码阅读]
    P1_OK --> P2B[Phase 2b: 知识查阅]
    P2A --> P2_OK[知识采集完成]
    P2B --> P2_OK

    P2_OK --> P3[Phase 3: 方案设计]
    P3 -->|骨架确认| P3_FILL[填充内容]
    P3_FILL --> P3_OK[系分文档]

    P3_OK --> P4{Phase 4: 多Agent评审}
    P4 -->|PASS: 0C+0H| P6[Phase 6: 日志汇总]
    P4 -->|FAIL| P5[Phase 5: 迭代修正]

    P5 -->|局部修复| P4
    P5 -->|架构级| P3
    P5 -->|需求错误| P1

    P6 --> Done([完成])
\`\`\`
```

实际生成时，根据本次执行的真实路径，用不同颜色/样式标注**实际走过的路径**和**跳过的分支**。

---

## Output Summary

```
./ai-coding-doc/
├── system-knowledge/           # 全局系统知识（7 个文件）
├── requirements/{date}-{name}/
│   ├── requirement-checklist.md
│   ├── code-reading-report.md
│   ├── design-doc.md
│   ├── review-report.md
│   └── log/                    # 完整执行日志
│       ├── phase0-*.md
│       ├── phase1-*.md
│       ├── phase2a-*.md
│       ├── phase2b-*.md
│       ├── phase3-*.md
│       ├── phase4-agent-*.md   # 5 个评审 Agent 各一个
│       ├── phase5-iteration-*.md
│       ├── execution-summary.md
│       └── execution-flowchart.md
└── reference/                  # 模板和参考文档
```

---

## Design Principles（设计此 skill 的底层逻辑）

来自 OpenAI Harness Engineering + Anthropic Claude Code Best Practices：

1. **上下文是最稀缺的资源** — 代码阅读和知识查阅用 subagent 执行，不污染主上下文
2. **不给验证手段就不可靠** — 每个阶段都有明确的产出和检查标准
3. **约束前置而非事后检查** — 架构 MUST/MUST NOT 在生成时就遵循，而非只在评审时才发现
4. **多视角胜过单视角深入** — 5 个角色并行评审覆盖面远大于 1 个全能评审员
5. **闭环迭代而非一次交付** — 生成→评审→修改→再评审，直到通过门禁
6. **骨架确认后再填充** — 避免方向错误后大量返工（对应 Anthropic 的 Explore→Plan→Implement 原则）
7. **代码为准，文档为辅** — 知识冲突时代码是 single source of truth
8. **系统知识复用** — 全局知识只生成一次，跨需求共享，增量更新
9. **过程可追溯** — 每个决策点、引用来源、执行步骤全部留痕，支持复盘和审计
