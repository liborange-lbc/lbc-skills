# ARCHITECTURE.md

## 模块边界与依赖方向

order-common <- order-infrastructure <- order-service <- order-api

| 模块 | 职责 | 不得包含 |
|------|------|----------|
| order-common | DTO、错误码、常量、枚举 | 业务逻辑、Spring Bean、DB 依赖 |
| order-infrastructure | DB 访问（MyBatis）、MQ 消费、外部 HTTP | Controller、业务编排 |
| order-service | 订单状态机、库存校验、事务编排 | HTTP 处理、直接 SQL |
| order-api | REST Controller、认证、参数校验 | DB 操作、业务计算 |

## 配置分层

application.yml < application-{profile}.yml < 环境变量 < 启动参数

敏感配置（DB 密码、API Key）必须通过环境变量或密钥管理服务注入，禁止写入配置文件。

## 错误处理

所有业务异常继承 `OrderException`，包含 `errorCode` 和 `message`。
通过 `GlobalExceptionHandler` 统一转换为 HTTP 响应。
禁止吞掉异常。第三方调用异常必须包装为 `OrderException`。

## 安全约束

- 凭证不得硬编码
- 日志中禁止输出用户手机号、身份证号等 PII 字段
- 所有 REST 端点必须经过认证（公开接口在 SecurityConfig 中显式放行）
- 外部 HTTP 调用必须设置 3s 连接超时和 10s 读取超时

## 测试策略

- Service 层：单元测试 + Mock，覆盖率 ≥ 60%
- API 层：集成测试，MockMvc
- Infrastructure 层：Testcontainers + H2

## AI 编码约束

- 改动前先读本文件
- 不跨模块边界修改
- 新增 REST 端点必须在 SecurityConfig 中配置权限
- 配置变更必须同步 application-example.yml
- 数据库 Schema 变更必须通过 Flyway migration