# TAIR缓存规范 **【蚂蚁专属】**

> ⚠️ **蚂蚁集团架构特殊要求**：本规范仅适用于蚂蚁集团TAIR双集群架构项目

## 🔴 P0级 - 双集群操作规范 **【蚂蚁专属·强制】**

### 1. 【强制】禁止直接覆盖双集群缓存值

**规范要求**：不要直接对双集群进行put值的覆盖，必须先invalid，再进行put操作；如果删除值，也必须进行invalid操作。

**蚂蚁专属原因**：MDB双机房独立集群架构下，数据同步有延迟。直接覆盖可能导致数据不一致问题。

**错误示例**：
```java
// ❌ 错误：直接覆盖，可能导致数据不一致
TairManager tairManager = ...;
tairManager.put(namespace, key, newValue);  // 直接覆盖！
```

**正确做法**：
```java
// ✅ 正确：先失效再更新
TairManager tairManager = ...;
String key = "myKey";

// 1. 先失效
ResultCode invalidResult = tairManager.invalid(namespace, key);
if (invalidResult.isSuccess()) {
    // 2. 失效成功后再put
    ResultCode putResult = tairManager.put(namespace, key, value);
}

// 删除时也要invalid
tairManager.invalid(namespace, key);
```

### 2. 【强制】数据库与缓存操作顺序 **【蚂蚁专属·强制】**

**规范要求**：任何操作，都是先保存数据库成功后，再进行缓存的新增、更新、清除操作。

**蚂蚁专属原因**：
- 确保数据一致性
- 避免缓存中有脏数据而数据库回滚的情况

**正确做法**：
```java
@Transactional
public void updateUser(User user) {
    // 1. 先更新数据库（确保事务成功）
    userDao.update(user);
    
    // 2. 数据库成功后，再操作缓存
    cacheService.invalidateUserCache(user.getId());
}
```

## 🟡 P1级 - 缓存使用最佳实践 **【蚂蚁专属·推荐】**

### 1. 【推荐】缓存key设计规范
- 使用业务前缀区分不同业务缓存
- key中避免包含特殊字符
- 考虑key的长度限制

### 2. 【推荐】缓存失效策略
- 设置合理的过期时间
- 考虑使用缓存预热机制
- 实现缓存降级策略

## 🔍 蚂蚁专属检查清单

### 代码审查时必须检查：
- [ ] **双集群操作**：所有缓存更新是否遵循invalid+put顺序
- [ ] **数据库优先**：是否先操作数据库再操作缓存
- [ ] **异常处理**：缓存操作失败时的回滚机制
- [ ] **监控告警**：是否配置了缓存命中率监控

### 常见蚂蚁专属陷阱：

| 陷阱类型 | 错误示例 | 蚂蚁专属风险 |
|----------|----------|--------------|
| 直接覆盖 | `tairManager.put(key, value)` | 双集群数据不一致 |
| 顺序错误 | 先缓存后数据库 | 脏数据风险 |
| 缺少invalid | 更新时未invalid旧值 | 数据版本冲突 |

---

**⚠️ 重要提醒**：以上规范仅适用于蚂蚁集团TAIR双集群架构，其他缓存系统不适用这些特殊要求。