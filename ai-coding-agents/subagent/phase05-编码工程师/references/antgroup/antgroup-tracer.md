# Tracer链路追踪规范 **【蚂蚁专属】**

> ⚠️ **蚂蚁集团架构特殊要求**：本规范仅适用于蚂蚁集团Tracer链路追踪系统

## 🔴 P0级 - 链路追踪规范 **【蚂蚁专属·强制】**

### 1. 【强制】异步线程上下文传递 **【蚂蚁专属·强制】**

**规范要求**：所有异步线程必须正确传递Tracer上下文，确保链路完整性。

**蚂蚁专属原因**：分布式链路追踪需要保持跨线程的traceId一致性。

**错误示例**：
```java
// ❌ 错误：异步线程丢失Tracer上下文
CompletableFuture.runAsync(() -> {
    // 这里无法获取到父线程的traceId
    log.info("处理业务逻辑"); // traceId丢失
});
```

**正确做法**：
```java
// ✅ 正确：传递Tracer上下文
Runnable task = TracerRunnable.wrap(() -> {
    // 保持traceId一致性
    log.info("处理业务逻辑"); // traceId正确传递
});
CompletableFuture.runAsync(task);

// 或者使用TracerExecutorService
TracerExecutorService tracerExecutor = new TracerExecutorService(executor);
tracerExecutor.submit(() -> {
    // traceId自动传递
    processBusinessLogic();
});
```

### 2. 【强制】线程池上下文传递 **【蚂蚁专属·强制】**

**规范要求**：自定义线程池必须包装Tracer上下文传递功能。

**正确配置**：
```java
// ✅ 正确：Tracer线程池配置
ThreadPoolExecutor executor = new ThreadPoolExecutor(
    5, 10, 60L, TimeUnit.SECONDS,
    new ArrayBlockingQueue<>(100),
    new ThreadFactoryBuilder().setNameFormat("biz-pool-%d").build(),
    new ThreadPoolExecutor.CallerRunsPolicy()
);

// 包装为Tracer线程池
ExecutorService tracerExecutor = new TracerExecutorService(executor);
```

## 🟡 P1级 - 链路追踪最佳实践 **【蚂蚁专属·推荐】**

### 1. 【推荐】Span命名规范
- 使用业务语义化的span名称
- 遵循`{系统}.{模块}.{操作}`格式

### 2. 【推荐】Tag规范
- 必须包含关键业务标识
- 避免包含敏感信息

### 3. 【推荐】错误处理
- 异常情况下必须记录error tag
- 包含错误码和错误信息

## 🔍 蚂蚁专属检查清单

### 代码审查时必须检查：
- [ ] **异步线程**：所有异步操作是否正确传递Tracer上下文
- [ ] **线程池**：自定义线程池是否使用Tracer包装
- [ ] **跨服务调用**：RPC调用是否保持traceId一致性
- [ ] **日志记录**：日志中是否正确包含traceId

### 常见蚂蚁专属陷阱：

| 陷阱类型 | 错误示例 | 蚂蚁专属风险 |
|----------|----------|--------------|
| 上下文丢失 | 异步线程无Tracer包装 | 链路断裂、问题定位困难 |
| 线程池未包装 | 使用原生线程池 | traceId无法传递 |
| 跨线程调用 | 手动创建Thread | 链路信息丢失 |

---

**⚠️ 重要提醒**：以上规范仅适用于蚂蚁集团Tracer链路追踪系统，其他链路追踪系统不适用这些特殊要求。