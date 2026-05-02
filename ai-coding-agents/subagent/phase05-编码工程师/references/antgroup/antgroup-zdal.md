# Zdal数据库访问规范 **【蚂蚁专属】**

> ⚠️ **蚂蚁集团架构特殊要求**：本规范仅适用于蚂蚁集团Zdal数据库中间件项目

## 🔴 P0级 - 数据库访问规范 **【蚂蚁专属·强制】**

### 1. 【强制】压测标识清理 **【蚂蚁专属·强制】**

**规范要求**：所有数据库操作完成后必须清理压测标识，避免影响生产数据。

**蚂蚁专属原因**：压测数据可能污染生产环境，造成数据混乱。

**正确做法**：
```java
// ✅ 正确：压测标识清理
try {
    // 设置压测标识（如需要）
    ZdalDataSource zdalDataSource = (ZdalDataSource) dataSource;
    zdalDataSource.setStressTestFlag(true);
    
    // 执行业务操作
    executeBusinessLogic();
    
} finally {
    // 必须清理压测标识
    zdalDataSource.setStressTestFlag(false);
}
```

### 2. 【强制】SQL翻译配置 **【蚂蚁专属·强制】**

**规范要求**：使用Zdal的SQL翻译功能时，必须正确配置翻译规则。

**正确配置**：
```xml
<!-- ✅ 正确：Zdal配置 -->
<bean id="zdalDataSource" class="com.alipay.zdal.datasource.ZdalDataSource">
    <property name="appName" value="your-app-name"/>
    <property name="dbmode" value="dev"/>
    <property name="configPath" value="zdal-config"/>
    <!-- SQL翻译配置 -->
    <property name="sqlTranslator" ref="sqlTranslator"/>
</bean>
```

## 🟡 P1级 - 数据库访问最佳实践 **【蚂蚁专属·推荐】**

### 1. 【推荐】分库分表策略
- 根据业务特点选择合适的分片键
- 避免跨分片的复杂查询

### 2. 【推荐】读写分离配置
- 读操作优先走从库
- 写操作必须走主库

## 🔍 蚂蚁专属检查清单

### 代码审查时必须检查：
- [ ] **压测标识**：是否在所有操作后清理压测标识
- [ ] **配置方式**：是否正确使用Zdal配置而非原生JDBC
- [ ] **分片策略**：分库分表配置是否合理
- [ ] **读写分离**：读写操作是否路由正确

### 常见蚂蚁专属陷阱：

| 陷阱类型 | 错误示例 | 蚂蚁专属风险 |
|----------|----------|--------------|
| 压测标识未清理 | 操作后未清理stressFlag | 生产数据污染 |
| 配置错误 | 使用原生DataSource | 无法使用Zdal特性 |
| 分片键选择 | 使用不合理分片键 | 数据分布不均 |

---

**⚠️ 重要提醒**：以上规范仅适用于蚂蚁集团Zdal数据库中间件，其他数据库中间件不适用这些特殊要求。