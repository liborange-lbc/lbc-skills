# SOFA RPC规范 **【蚂蚁专属】**

> ⚠️ **蚂蚁集团架构特殊要求**：本规范仅适用于蚂蚁集团SOFA RPC技术栈项目

## 🔴 P0级 - RPC配置规范 **【蚂蚁专属·强制】**

### 1. 【强制】超时设置 **【蚂蚁专属·强制】**

**规范要求**：调用远程操作必须有超时设置，需要明确设置Timeout。

**蚂蚁专属原因**：防止线程长时间阻塞，避免级联故障。

**错误示例**：
```xml
<!-- ❌ 错误：未设置超时 -->
<sofa:reference id="xxxService" interface="com.alipay.XxxService">
    <sofa:binding.tr/>
</sofa:reference>
```

**正确做法**：
```xml
<!-- ✅ 正确：设置超时时间 -->
<sofa:reference id="xxxService" interface="com.alipay.XxxService">
    <sofa:binding.tr>
        <sofa:global-attrs timeout="3000"/>
    </sofa:binding.tr>
</sofa:reference>
```

或注解方式：
```java
@SofaReference(binding = @SofaBinding(bindingType = "tr", timeout = 3000))
private XxxService xxxService;
```

### 2. 【强制】单元化架构VIP配置 **【蚂蚁专属·强制】**

**规范要求**：
- 单元化架构机房里的系统，进行SOFA RPC调用时，调用方必须要配置VIP
- 非单元化架构机房里的系统，则一定不能配置VIP

**蚂蚁专属原因**：
- 单元化架构：跨机房调用，强依赖VIP配置
- 非单元化架构：大部分运维层面不提供VIP域名，配置可能导致启动失败

**单元化架构配置**：
```xml
<!-- ✅ 单元化架构必须配置VIP -->
<sofa:reference id="xxxService" interface="com.alipay.XxxService">
    <sofa:binding.tr>
        <compatible>
            <!-- PROVIDER_tr_service_url:形如 cif-pool.{inner_domain}:12200 -->
            <vip url="${PROVIDER_tr_service_url}"></vip>
        </compatible>
    </sofa:binding.tr>
</sofa:reference>
```

### 3. 【强制】协议使用规范 **【蚂蚁专属·强制】**

**规范要求**：
- 禁止使用"reliable tr"协议
- 新接口禁止使用ws协议

### 4. 【强制】Hessian序列化规范 **【蚂蚁专属·强制】**

**规范要求**：Hessian序列化，子类不能包含与父类相同名称的域变量。

**蚂蚁专属原因**：Hessian序列化机制可能导致字段值被覆盖或丢失。

**错误示例**：
```java
// ❌ 错误：子类与父类同名字段
public class BaseRequest {
    private String id;
}

public class UserRequest extends BaseRequest {
    private String id;  // 错误！与父类同名
}
```

**正确做法**：
```java
// ✅ 正确：避免字段名冲突
public class BaseRequest {
    private String requestId;
}

public class UserRequest extends BaseRequest {
    private String userId;  // 不同名字段
}
```

## 🟡 P1级 - 序列化最佳实践 **【蚂蚁专属·推荐】**

### 1. 【推荐】默认构造方法
建议提供默认构造方法，便于Hessian反序列化。

```java
public class UserDTO implements Serializable {
    private static final long serialVersionUID = 1L;
    
    // 建议提供默认构造方法
    public UserDTO() {
    }
    
    public UserDTO(String name, Integer age) {
        this.name = name;
        this.age = age;
    }
}
```

## 🔍 蚂蚁专属检查清单

### 代码审查时必须检查：
- [ ] **超时配置**：所有RPC调用是否设置了超时时间
- [ ] **VIP配置**：单元化架构是否正确配置了VIP
- [ ] **协议检查**：是否使用了禁止的协议
- [ ] **序列化**：是否存在父子类字段名冲突
- [ ] **异常处理**：RPC调用失败时的降级策略

### 环境配置检查：
```bash
# 检查是否为单元化架构
echo $IS_CELLULAR_ARCH  # 应该为true/false

# 检查VIP配置
echo $PROVIDER_tr_service_url  # 单元化架构下必须配置
```

### 常见蚂蚁专属陷阱：

| 陷阱类型 | 错误示例 | 蚂蚁专属风险 |
|----------|----------|--------------|
| 无超时设置 | 未配置timeout属性 | 线程阻塞级联故障 |
| VIP配置错误 | 非单元化配置VIP | 服务启动失败 |
| 协议误用 | 使用reliable tr协议 | 兼容性问题 |
| 字段冲突 | 父子类同名字段 | 序列化数据丢失 |

---

**⚠️ 重要提醒**：以上规范仅适用于蚂蚁集团SOFA RPC技术栈，其他RPC框架不适用这些特殊要求。