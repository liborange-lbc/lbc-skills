---
name: ai-coding-agents
description: >-
  全流程编码流水线：需求澄清 → 知识采集 → 系分编写 → 系分评审 → 编码实现 → 代码CR → 测试验证 → 交付报告。
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
PROJECT_ROOT: "."                        # 用户项目根目录（默认当前工作目录）
OUTPUT_DIR: ".ai-coding"                 # 产出目录（相对于 PROJECT_ROOT）
# 需求目录 = {PROJECT_ROOT}/{OUTPUT_DIR}/{yyyyMMdd}-{需求名称}/
# 示例: .ai-coding/20260501-用户注册/

# TECH_STACK 由主Agent在 Phase 1 结束后自动填写（从代码推断或用户确认）。
# 未填写时流水线仍可运行，仅影响 P7 测试命令和部分检查项的精度。
TECH_STACK:
  language: ""                           # Java | TypeScript | Python | Go | ...
  framework: ""                          # Spring Boot | Next.js | FastAPI | ...
  test_framework: ""                     # JUnit | Jest | Pytest | ...
  build_tool: ""                         # Maven | npm | pip | ...
  architecture: ""                       # microservice | monolith | modular-monolith

# === 扩展文档挂载 ===
# type: feishu | confluence | local | git | url
# 每个阶段可挂载多份文档，启动对应角色时自动注入。
EXTENSION_DOCS:
  requirement: []     # 产品PRD、业务流程图 → collector
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

## 流水线启动前置

流水线启动时，主Agent必须在 Phase 1 之前完成以下初始化。

### Step 0: 路径解析（必须最先执行）

```
# 解析 SKILL_DIR — 后续所有 skill 内部文件读取基于此路径
Bash: dirname "$(find ~/.claude/skills -path '*/ai-coding-agents/SKILL.md' -print -quit 2>/dev/null)"
→ 将输出保存为 SKILL_DIR（如 /Users/xxx/.claude/skills/ai-coding-agents）

# 解析需求目录
需求目录 = {PROJECT_ROOT}/{OUTPUT_DIR}/{yyyyMMdd}-{需求名称}/
# 示例: .ai-coding/20260501-用户注册/
# yyyyMMdd 取流水线启动当天日期
```

### Step 1: Dashboard 自动启动

```
# 检查 Dashboard 是否已在运行
Bash: curl -s http://localhost:8080/api/dirs >/dev/null 2>&1 && echo "RUNNING" || echo "NOT_RUNNING"

# 如果未运行，后台启动（SKILL_DIR 已在 Step 0 解析）
Bash(run_in_background: true):
  python3 ${SKILL_DIR}/dashboard/server.py --project-root ${PROJECT_ROOT} --port 8080
→ 等待 1s 后验证: curl -s http://localhost:8080/api/dirs
→ 8080 被占用则尝试 8081、8082
→ 全部失败则提示用户手动执行

# 如果已运行，直接告知用户
→ 输出: "Dashboard 已运行: http://localhost:8080"
```

### Step 2: 预加载工具

```
# 确保修正循环所需的 SendMessage 工具可用
ToolSearch(query: "select:SendMessage")
```

---

## 主Agent行为准则

1. **纯调度不执行** — 绝不直接编辑代码文件，绝不直接读子Agent产出内容
2. **Grep提取判定** — 只用 Grep 提取评审报告的 PASS/FAIL + 统计行
3. **Task驱动** — 每个 Phase 开始前 TaskCreate，完成后 TaskUpdate
4. **日志记录** — 通过 `${SKILL_DIR}/tools/log-event.sh` 脚本记录事件（禁止手动 Edit 写入时间）
   - **调用方式**: `Bash: bash ${SKILL_DIR}/tools/log-event.sh {日志路径} {Phase} {Agent名称} {agentId} {事件} "备注"`
   - 脚本自动生成精确到秒的时间戳（`YYYY-MM-DD HH:MM:SS`），自动递增序号，自动校验事件枚举
   - **即时记录**: 启动子Agent后**立即**调用脚本记录「启动」，收到返回后**立即**记录「完成/PASS/FAIL」，禁止延迟批量记录
   - 事件类型只能用枚举值：`启动` | `完成` | `PASS` | `FAIL` | `Resume` | `降级新建`（见 [reference/执行日志规范.md](reference/执行日志规范.md)）
   - Agent名称只能用枚举值（如 "P5-编码工程师"），见执行日志规范 Agent 名称表
   - **仅追加不修改**；Dashboard 从此表派生所有 Phase 状态
   - 子 Agent 不关心本表，只聚焦自身业务；主 Agent 负责所有记录
5. **扩展文档转发** — 启动子Agent时将 EXTENSION_DOCS 对应路径注入 prompt
6. **AgentID管理** — agentId 记录在执行记录表中，修正循环时从表中 Grep 查找
7. **工具预加载** — 流水线启动时用 ToolSearch 预加载 SendMessage 工具，确保修正循环可用

### 子Agent Prompt 组装规范

子Agent运行在用户项目目录下，**无法访问skill安装目录**。主Agent必须将所需参考内容注入prompt。

**组装步骤**（每次启动子Agent前执行）:

1. Read `${SKILL_DIR}/subagent/{phase目录}/{执行指南}.md` → 获取指南全文
2. Read 执行指南中引用的参考文件（如评审检查清单、架构约束）→ 获取内容
3. 按以下模板组装prompt:

```
你是 {角色中文名}，执行 Phase {N}。

## 你的执行指南
{执行指南.md 全文 — 去掉其中的文件链接，因为你无法访问skill目录}

## 参考文件
### {文件名，如 评审检查清单}
{参考文件内容 — 仅注入与本角色相关的章节}

## Input 文件路径（请用 Read 工具读取）
- {需求目录}/需求清单.md
- {需求目录}/系分文档.md
- ...（按执行指南 Input 表列出）

## 产出写入路径
- {需求目录}/{产出文件名}
- {需求目录}/log/{日志文件名}

## 扩展文档（如有）
- {EXTENSION_DOCS 对应项的路径}
```

**各Phase注入清单**:

| Phase | 执行指南 | 需注入的参考文件 |
|-------|---------|----------------|
| P1 | phase01-需求访谈员/需求面试清单.md | 无 |
| P2 | phase02-知识采集员/代码阅读指南.md | 知识查阅规则.md |
| P3 | phase03-系分设计师/系分编写执行指南.md | 架构约束.md + 设计文档模板.md + references/db.md |
| P4 | phase04-系分评审员/系分评审执行指南.md | 评审检查清单.md（对应角色章节）+ 架构约束.md（仅design-reviewer） |
| P5 | phase05-编码工程师/编码实现指南.md | references/ 下规范按需加载（不全量注入）+ examples/ |
| P6 | phase06-代码评审员/代码评审执行指南.md | references/（含 checklist + script + templates）|
| P7 | phase07-测试工程师/测试验证指南.md | 无 |

### Agent 生命周期管理

#### 首次启动子Agent（所有 Phase 的子Agent）

**适用范围**: P1 interviewer、P2 collector、P3 designer、P5 coder、P7 tester，以及 P4/P6 的每个 reviewer。所有子Agent 启动时都必须记录，不可遗漏。

主Agent必须执行以下步骤：

```
# Step 1: 启动子Agent
调用工具: Agent(
  description: "P5 coder 编码实现",
  prompt: "你是 coder（编码工程师）...{完整prompt}..."
)

# Step 2: 从返回结果末尾提取 agentId
# 返回格式示例: "agentId: af12833733cee1482 (use SendMessage with to: 'af12833733cee1482' to continue)"

# Step 3:【立即】记录「启动」— 不等 Agent 返回结果
Bash: bash ${SKILL_DIR}/tools/log-event.sh \
  "{需求目录}/log/执行日志.md" P5 P5-编码工程师 af12833733cee1482 启动 "编码实现"

# Step 4: Agent 返回结果后，【立即】记录「完成」（评审 Agent 用 PASS/FAIL）
Bash: bash ${SKILL_DIR}/tools/log-event.sh \
  "{需求目录}/log/执行日志.md" P5 P5-编码工程师 af12833733cee1482 完成 "修改 app.js + style.css"

# Step 5: 确认 SendMessage 工具可用（首次时）
调用工具: ToolSearch(query: "select:SendMessage")
```

> **禁止**: 用 Edit 手写时间戳；等多个事件完成后再批量记录。
> **必须**: 每个事件发生时立即调用 log-event.sh，确保时间戳反映真实执行时刻。

#### 修正循环 — Resume 同一子Agent（关键路径）

当 P4/P6 评审 FAIL，主Agent必须执行以下步骤（每一步都追加执行记录行）：

```
# ═══ P4 FAIL → Resume designer 修复系分 ═══

# Step 1: 从 Agent 执行记录中 Grep designer 的 agentId
Grep: 执行日志.md 中 "P3-系分设计师" → 提取 agentId

# Step 2: Grep 提取评审问题摘要（不读全文）
Grep: log/phase4-评审-*.md 中 "CRITICAL\|HIGH" 行 → 汇总问题列表

# Step 3:【立即】记录「Resume」→ 然后 Resume designer
Bash: bash ${SKILL_DIR}/tools/log-event.sh \
  "{需求目录}/log/执行日志.md" P3 P3-系分设计师 {agentId} Resume "P4评审FAIL，修复系分"
调用工具: SendMessage(
  to: "{agentId}",
  message: "P4 评审发现以下问题需要修复:
    1. [HIGH] {具体问题描述} — 建议: {评审建议}
    评审报告路径: {需求目录}/log/phase4-评审-需求完整度.md
    请逐条修复后更新系分文档，完成后告知。"
)

# Step 4: 修复完成后【立即】记录「完成」
Bash: bash ${SKILL_DIR}/tools/log-event.sh \
  "{需求目录}/log/执行日志.md" P3 P3-系分设计师 {agentId} 完成 "修复完成"

# Step 5: Resume reviewers 复审（每个事件立即记录）
Bash: bash ${SKILL_DIR}/tools/log-event.sh \
  "{需求目录}/log/执行日志.md" P4 P4-需求完整度评审员 {reviewer_agentId} Resume "复审"
调用工具: SendMessage(to: "{reviewer_agentId}", message: "designer 已修复问题，请重新评审...")
# 复审完成后【立即】记录:
Bash: bash ${SKILL_DIR}/tools/log-event.sh \
  "{需求目录}/log/执行日志.md" P4 P4-需求完整度评审员 {reviewer_agentId} PASS "复审 0C/0H/0M/0L"

# ═══ P6 FAIL → Resume coder 修复代码 ═══
# 流程同上，将 P3/designer 替换为 P5/coder，P4/reviewer 替换为 P6/reviewer

# Step 1: Grep "P5-编码工程师" 提取 agentId
# Step 2: Grep CR 问题摘要
# Step 3: 追加 Resume 行 + SendMessage(to: "{coder_agentId}")
# Step 4: 修复完成后追加 完成 行
# Step 5: Resume CR reviewers + 追加 PASS/FAIL 行
```

#### 修正循环产出规范

- 修复后的评审结果必须写入 **`-复审.md`** 后缀文件（如 `phase6-CR-需求实现度-复审.md`）
- 不覆盖原始评审文件（保留修正历史）
- 迭代日志写入 `log/phase{N}-迭代-{轮次}.md`

#### Resume 失败的降级策略

如果 SendMessage 工具不可用（ToolSearch 返回空或工具调用被拒绝）：

```
# 降级: 新建 Agent，但必须传入完整上下文
调用工具: Agent(
  description: "P6 修正循环 — Resume coder (降级为新建)",
  prompt: "你是 coder（编码工程师），这是修正循环...
    【重要】你之前已经实现了以下代码（降级模式，需重新阅读）:
    - 读取文件: {文件路径列表}
    - 修复问题: {问题列表}
    ..."
)

# 必须在执行记录中追加「降级新建」事件
Edit: 执行日志.md → Agent 执行记录表追加:
  | {seq} | {time} | P5 | P5-编码工程师 | {new_agentId} | 降级新建 | SendMessage不可用 |
```

#### Resume vs 新建的判定表

| 场景 | 操作 | 具体工具调用 | 执行记录事件 |
|------|------|-------------|-------------|
| P4 FAIL，局部问题 | Resume designer | `SendMessage(to: "{designer_agentId}")` | Resume → 完成 |
| P6 FAIL，局部问题 | Resume coder | `SendMessage(to: "{coder_agentId}")` | Resume → 完成 |
| 评审后复审 | Resume reviewer | `SendMessage(to: "{reviewer_agentId}")` | Resume → PASS/FAIL |
| 架构级问题需重做 | 新建 Agent | `Agent(description: "P3 designer 重做")` | 启动 → 完成 |
| 需求理解错误 | 回退P1全流程 | `Agent(description: "P1 interviewer 重做")` | 启动 → 完成 |
| SendMessage 不可用 | 降级新建 | `Agent(prompt: "...[含完整上下文]...")` | 降级新建 → 完成 |

### 并行Agent执行

Phase 4（3个评审）和 Phase 6（3个CR）用 `Agent(run_in_background: true)` 并行启动：

```
# Step 1: 并行启动 3 个 reviewer（单条消息中发 3 个 Agent 调用）
调用工具（并行）:
  Agent(description: "P4 design-reviewer", run_in_background: true, prompt: "...")
  Agent(description: "P4 perf-reviewer", run_in_background: true, prompt: "...")
  Agent(description: "P4 req-reviewer", run_in_background: true, prompt: "...")

# Step 2: 提取 agentId，【立即】逐个记录「启动」（每个 Agent 启动后立即调用脚本）
Bash: bash ${SKILL_DIR}/tools/log-event.sh "{需求目录}/log/执行日志.md" P4 P4-架构评审员 {agentId1} 启动 "架构评审"
Bash: bash ${SKILL_DIR}/tools/log-event.sh "{需求目录}/log/执行日志.md" P4 P4-性能评审员 {agentId2} 启动 "性能评审"
Bash: bash ${SKILL_DIR}/tools/log-event.sh "{需求目录}/log/执行日志.md" P4 P4-需求完整度评审员 {agentId3} 启动 "需求完整度评审"

# Step 3: 等待所有完成通知（自动通知，不需要轮询）

# Step 4: Grep 提取判定结果
Grep: log/phase4-评审-架构.md → "## 判定" 行
Grep: log/phase4-评审-性能.md → "## 判定" 行
Grep: log/phase4-评审-需求完整度.md → "## 判定" 行

# Step 5: 每个 Agent 返回后【立即】记录 PASS/FAIL（不等全部完成再批量写入）
Bash: bash ${SKILL_DIR}/tools/log-event.sh "{需求目录}/log/执行日志.md" P4 P4-架构评审员 {agentId1} PASS "0C/0H/2M/1L"
Bash: bash ${SKILL_DIR}/tools/log-event.sh "{需求目录}/log/执行日志.md" P4 P4-性能评审员 {agentId2} PASS "0C/0H/0M/1L"
Bash: bash ${SKILL_DIR}/tools/log-event.sh "{需求目录}/log/执行日志.md" P4 P4-需求完整度评审员 {agentId3} FAIL "1C/0H/0M/0L"
```

---

## Workflow

```
P1 需求澄清 → P2 知识采集 → P3 系分编写 → P4 系分评审 ⇄ 修正(≤3轮)
interviewer    collector      designer      3×reviewer    Resume designer
                                                ↓ PASS
                                           P5 编码实现 → P6 代码CR ⇄ 修正(≤3轮)
                                             coder       3×reviewer  Resume coder
                                                              ↓ PASS
                                                    P7 测试验证 ⇄ 修正(≤3轮)
                                                      tester      Resume coder
                                                          ↓ PASS
                                                     P8 交付报告
                                                       主Agent

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

**执行者**: collector 子Agent  
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

按 **9 步设计流程** 推进，每步确认后再进入下一步：

1. **需求与范围澄清** — 提炼核心功能、约束、排除范围
2. **架构与模块划分** — 功能架构 + 集成架构 + 部署架构（同城双机房、无单点），生成骨架后返回主Agent，主Agent转交用户确认
3. **数据模型与存储** — 遵循数据库设计规范，版本兼容性设计
4. **接口设计** — oneapi/对外/内部/依赖服务接口，兼容性设计
5. **功能模块设计** — 逐模块深入分析，时序图 + 状态图
6. **非功能性需求设计** — 稳定性/高可用/安全/性能/扩展性
7. **变更三板斧** — 可监控/可灰度/可应急
8. **产出设计文档** — 按模板整理 + 需求追踪矩阵
9. **方案检查** — 架构/接口/数据库/安全/三板斧全面自检

架构约束 → [subagent/phase03-系分设计师/架构约束.md](subagent/phase03-系分设计师/架构约束.md)  
文档模板 → [subagent/phase03-系分设计师/设计文档模板.md](subagent/phase03-系分设计师/设计文档模板.md)  
数据库规范 → [subagent/phase03-系分设计师/references/db.md](subagent/phase03-系分设计师/references/db.md)

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
**FAIL 时主Agent必须执行**:
1. Grep 提取 CRITICAL/HIGH 问题列表（不读评审全文）
2. `SendMessage(to: "{designer_agentId}")` — Resume designer 修复（参见 §主Agent行为准则-修正循环）
3. designer 修复完成后 `SendMessage(to: "{reviewer_agentId}")` — Resume reviewers 复审
4. 复审结果写入 `log/phase4-评审-{视角}-复审.md`
5. 最多 MAX_ITERATION 轮，超限标记 ⚠️

修正协议 → [reference/修正循环协议.md](reference/修正循环协议.md)

---

## Phase 5: 编码实现

**执行者**: 1~N 个 coder 子Agent（按模块依赖分层并行，可 Resume）  
**挂载**: EXTENSION_DOCS.coding

**主Agent编排**（启动 coder 前执行）：
1. **依赖分析** — 从系分文档提取模块间调用关系、外键关系、公共代码依赖
2. **拓扑排序分层** — Layer -1(公共) → Layer 0(无依赖) → Layer 1(依赖L0) → ...
3. **按层级并行启动 coder** — 同层模块并行，跨层串行等待
4. 编排计划写入 `log/phase5-编排计划.md`

**每个 coder 执行 5 阶段工作流**（READ→TEST→IMPL→CHECK→DOCS）：
1. **READ** — 读取系分方案 + 按需加载规范（references/ 下 antdigital/antgroup/基础Java 规范）
2. **TEST** — TDD，先生成单测再实现（AAA 模式）
3. **IMPL** — 按 Entity→Mapper→Service→Controller 顺序实现
4. **CHECK** — L1 静态检查 + L2 动态验证（mvn compile/test）
5. **DOCS** — 同步更新架构文档 + 模块文档

详细指南 → [subagent/phase05-编码工程师/编码实现指南.md](subagent/phase05-编码工程师/编码实现指南.md)

---

## Phase 6: 代码 CR

**执行者**: 3个并行 reviewer 子Agent（SDD 模式结构化审查）  
**挂载**: EXTENSION_DOCS.review + EXTENSION_DOCS.coding

| Agent | 视角 | 检查维度 | 详细checklist |
|-------|------|---------|--------------|
| code-quality-reviewer | 代码质量 | 可读性(A1-A7) + 可靠性(军规) + Bug模式(B/M/I) + 自定义 | [references/readability-checklist.md](subagent/phase06-代码评审员/references/readability-checklist.md) + [reliability-checklist.md](subagent/phase06-代码评审员/references/reliability-checklist.md) + [bug-pattern-checklist.md](subagent/phase06-代码评审员/references/bug-pattern-checklist.md) |
| code-security-reviewer | 安全漏洞 | 安全 + Bug模式(安全类) | [security-checklist.md](subagent/phase06-代码评审员/references/security-checklist.md) + [bug-pattern-checklist.md](subagent/phase06-代码评审员/references/bug-pattern-checklist.md) |
| **code-req-reviewer** | **需求实现完整度** | 功能性检查(REQ核对) + 证据约束 | 逐条在代码中验证，P0 须同时给出 spec 证据 + 代码证据 |

**执行流程**: GitNexus 影响面扩展审查范围 → `scan-all-rules.sh` 自动化预扫（52/222条可程序化规则）→ LLM 逐文件补全。严重性等级：P0(CRITICAL) / P1(HIGH) / P2(MEDIUM)。

**Pass Criteria**: 0 P0/CRITICAL + 0 P1/HIGH + 需求实现100%  
**FAIL 时主Agent必须执行**:
1. Grep 提取 CRITICAL/HIGH 问题列表（含文件:行号 + 规则ID）
2. `SendMessage(to: "{coder_agentId}")` — Resume coder 修复代码（参见 §主Agent行为准则-修正循环）
3. coder 修复完成后 `SendMessage(to: "{cr_reviewer_agentId}")` — Resume CR reviewers 复审
4. 复审结果写入 `log/phase6-CR-{视角}-复审.md`
5. 最多 MAX_ITERATION 轮，超限标记 ⚠️

---

## Phase 7: 测试验证

**执行者**: tester 子Agent  
**挂载**: EXTENSION_DOCS.testing

1. 运行测试 + lint + typecheck
2. **GitNexus 影响面分析** — `gitnexus detect-changes` 检查变更影响范围，确认测试覆盖所有受影响模块
3. 逐条需求确认测试通过
4. **更新需求清单状态** — 测试通过的需求标记为 ✅，未通过标记为 ❌
5. **测试报告需求表** — 需求ID 旁必须附带需求描述（如 "R01 回路箭头触发"），不能仅写 ID

**Pass Criteria**: 全部测试通过 + 需求覆盖100%  
**FAIL 时主Agent必须执行**:
1. Grep 提取测试报告中 FAIL 的 Case 和未覆盖需求
2. `SendMessage(to: "{coder_agentId}")` — Resume coder 修复代码
3. coder 修复完成后 `SendMessage(to: "{tester_agentId}")` — Resume tester 重新验证
4. 复验结果写入 `log/phase7-迭代-{轮次}.md`
5. 最多 MAX_ITERATION 轮，超限标记 ⚠️

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
├── {yyyyMMdd}-{需求名称}/                   # 每个需求独立目录（日期前缀按启动日）
│   ├── 需求清单.md                         # Phase 1 产出（带全生命周期状态）
│   ├── 代码阅读报告.md                     # Phase 2 产出
│   ├── 知识摘要.md                         # Phase 2 产出
│   ├── 系分文档.md                         # Phase 3 产出
│   ├── 需求追踪矩阵.md                     # Phase 3 产出
│   ├── 交付报告.md                         # Phase 8 产出
│   └── log/                               # 执行日志（主Agent记录状态，子Agent写独立log）
│       ├── 执行日志.md                     # Agent 执行记录（Dashboard 状态唯一来源）
│       ├── phase1-需求澄清.md
│       ├── phase2-知识采集.md
│       ├── phase3-系分编写.md
│       ├── phase4-评审-架构.md              # 子Agent独立文件
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
| collector | 需求清单、代码库、GitNexus索引 | 其他Agent产出 |
| designer | 需求清单、代码阅读报告、知识摘要（骨架通过主Agent转交用户确认） | 代码文件、用户直接对话 |
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
| P1 | 需求清单.md | 每条需求有验收标准、无"待定" | P2 collector, P3 designer, P4/P6 reviewer |
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
