# 代码阅读指南

> planner 子Agent 在 Phase 2 使用。双路并行：六步下钻法 + GitNexus 知识图谱。

## 前置：GitNexus 索引

在开始代码阅读前，先对项目建立知识图谱索引：

```bash
# 索引项目（首次执行，后续增量更新）
gitnexus analyze {PROJECT_ROOT} --name {project-name}

# 验证索引状态
gitnexus status
```

如果项目已有索引（`gitnexus list` 可查），跳过此步。

---

## 双路并行策略

| 路径 | 工具 | 适合场景 |
|------|------|---------|
| 六步下钻法 | Read + Grep + Glob | 深入理解单个模块的完整实现细节 |
| GitNexus | gitnexus context/query/impact | 快速定位符号关系、跨模块调用链、影响面 |

**推荐流程**: 先用 GitNexus 快速建立全局视图，再用六步下钻法深入关键模块。

---

## GitNexus 代码分析命令

### 符号360度分析
```bash
# 查看某个类/函数的完整上下文：谁调用它、它调用谁、关联流程
gitnexus context {SymbolName} -r {project-name} --content
```

### 执行流搜索
```bash
# 用自然语言搜索相关代码流程
gitnexus query "用户注册流程" -r {project-name} --goal "找到注册相关的全部代码路径"
```

### 影响面分析
```bash
# 查看修改某符号会影响哪些上游依赖
gitnexus impact {SymbolName} -r {project-name} --direction upstream --depth 3

# 查看某符号依赖的下游
gitnexus impact {SymbolName} -r {project-name} --direction downstream --depth 3
```

### Cypher 自定义查询
```bash
# 复杂的多跳分析
gitnexus cypher "MATCH (a)-[r]->(b) WHERE a.name='UserService' RETURN b.name, type(r)" -r {project-name}
```

---

## 六步下钻法

### Step 1: 模块入口
- **查找**: Controller / Router / Handler / API endpoint
- **读取**: URL patterns, request/response 类型, 鉴权注解
- **记录**: 入口清单 + 现有接口列表

### Step 2: 领域模型
- **查找**: Entity / Model / Schema / Table
- **读取**: 字段类型、关联关系、枚举、约束
- **记录**: 数据模型图 + 关键字段说明

### Step 3: 核心业务流程
- **查找**: Service / UseCase / Handler 实现
- **读取**: 事务边界、锁机制、校验逻辑、外部调用
- **记录**: 核心调用链 + 业务规则

### Step 4: 数据访问
- **查找**: Repository / DAO / Mapper / Query
- **读取**: 复杂查询、索引使用、批量操作
- **记录**: 查询模式 + 性能风险点

### Step 5: 边界交互
- **查找**: 外部服务调用、消息队列、缓存、定时任务
- **读取**: 失败处理、重试策略、幂等机制
- **记录**: 依赖关系图 + 故障模式

### Step 6: 配置与基础设施
- **查找**: 配置文件、迁移脚本、CI/CD
- **读取**: 环境差异、功能开关
- **记录**: 配置清单

---

## 产出格式

```markdown
# 代码阅读报告

## 模块概览
- 涉及模块: {模块列表}
- 技术栈: {语言/框架/数据库}
- GitNexus索引: {project-name} ({N}文件, {N}符号, {N}边)

## 入口清单
| 接口 | 方法 | 路径 | 鉴权 |
|------|------|------|------|

## 数据模型
{ER图或表格}

## 核心调用链
{时序图或 GitNexus context 输出}

## 依赖关系
{GitNexus impact 输出 或 依赖图}

## 风险标记
| # | 风险 | 位置 | 影响 |
|---|------|------|------|

## 现有约束
{已有的幂等/事务/缓存机制}
```
