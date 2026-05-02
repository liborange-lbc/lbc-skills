# DRM配置管理规范 **【蚂蚁专属】**

> ⚠️ **蚂蚁集团架构特殊要求**：本规范仅适用于蚂蚁集团DRM配置中心项目

## 🔴 P0级 - 配置管理规范 **【蚂蚁专属·强制】**

### 1. 【强制】配置更新策略 **【蚂蚁专属·强制】**

**规范要求**：配置更新必须实现幂等处理，避免重复更新导致的问题。

**蚂蚁专属原因**：配置可能多次推送，必须保证幂等性。

**正确做法**：
```java
// ✅ 正确：幂等配置更新
@DRMListener(dataId = "payment.config")
public class PaymentConfigListener implements DRMListenerInterface {
    
    private volatile PaymentConfig cachedConfig;
    
    @Override
    public void onChange(String dataId, String configValue) {
        // 1. 幂等判断：检查版本号或MD5
        String newMd5 = MD5Util.md5(configValue);
        if (newMd5.equals(cachedConfig.getMd5())) {
            return; // 配置未变化，跳过更新
        }
        
        // 2. 更新配置
        PaymentConfig newConfig = parseConfig(configValue);
        newConfig.setMd5(newMd5);
        cachedConfig = newConfig;
        
        // 3. 刷新相关组件
        refreshComponents(newConfig);
    }
}
```

### 2. 【强制】回调规范 **【蚂蚁专属·强制】**

**规范要求**：配置变更回调必须正确处理异常，避免影响配置中心稳定性。

**正确做法**：
```java
// ✅ 正确：异常安全的回调处理
@DRMListener(dataId = "system.config")
public class SystemConfigListener implements DRMListenerInterface {
    
    @Override
    public void onChange(String dataId, String configValue) {
        try {
            // 业务配置更新
            updateSystemConfig(configValue);
            
        } catch (Exception e) {
            // 异常处理：记录日志但不抛出异常
            log.error("配置更新失败, dataId: {}, config: {}", dataId, configValue, e);
            
            // 可选：发送告警
            alertService.sendConfigUpdateAlert(dataId, e.getMessage());
        }
    }
}
```

## 🟡 P1级 - 配置管理最佳实践 **【蚂蚁专属·推荐】**

### 1. 【推荐】配置版本管理
- 使用版本号管理配置变更
- 支持配置回滚机制

### 2. 【推荐】灰度发布
- 支持按用户、机器维度灰度
- 配置变更可回滚

## 🔍 蚂蚁专属检查清单

### 代码审查时必须检查：
- [ ] **幂等处理**：配置更新是否实现了幂等逻辑
- [ ] **异常处理**：回调方法是否捕获所有异常
- [ ] **版本管理**：是否支持配置版本控制
- [ ] **灰度策略**：是否支持灰度发布

### 配置检查：
```properties
# 蚂蚁专属配置检查
# 配置中心地址
drm.server.address=drm.server.antgroup.com

# 配置版本管理
drm.config.version.enabled=true
drm.config.rollback.enabled=true
```

### 常见蚂蚁专属陷阱：

| 陷阱类型 | 错误示例 | 蚂蚁专属风险 |
|----------|----------|--------------|
| 无幂等处理 | 重复更新配置 | 配置混乱 |
| 异常未捕获 | 回调抛出异常 | 配置中心不稳定 |
| 无版本管理 | 无法回滚配置 | 配置错误无法恢复 |

---

**⚠️ 重要提醒**：以上规范仅适用于蚂蚁集团DRM配置中心，其他配置中心不适用这些特殊要求。