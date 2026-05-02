# 二方库规范 **【蚂蚁专属】**

> ⚠️ **蚂蚁集团架构特殊要求**：本规范仅适用于蚂蚁集团内部二方库管理

## 🔴 P0级 - 二方库规范 **【蚂蚁专属·强制】**

### 1. 【强制】GAV坐标规范 **【蚂蚁专属·强制】**

**规范要求**：二方库的GroupId、ArtifactId、Version必须遵循蚂蚁集团统一规范。

**命名格式**：
- **GroupId**: `com.antgroup.{业务域}.{子系统}`
- **ArtifactId**: `{子系统}-{模块名}`
- **Version**: 遵循语义化版本规范

**正确示例**：
```xml
<!-- ✅ 正确：蚂蚁二方库GAV -->
<dependency>
    <groupId>com.antgroup.payment.order</groupId>
    <artifactId>order-api</artifactId>
    <version>1.2.3</version>
</dependency>
```

**错误示例**：
```xml
<!-- ❌ 错误：不符合蚂蚁规范 -->
<dependency>
    <groupId>com.example</groupId>
    <artifactId>my-lib</artifactId>
    <version>1.0</version>
</dependency>
```

### 2. 【强制】版本号管理 **【蚂蚁专属·强制】**

**规范要求**：
- 使用语义化版本号：主版本.次版本.修订版本
- 禁止SNAPSHOT版本上生产
- 重大变更必须升级主版本号

**版本号规则**：
```
主版本.次版本.修订版本
  │      │      │
  │      │      └── 修订版本：bug修复
  │      └── 次版本：向后兼容的功能新增
  └── 主版本：不兼容的API变更
```

## 🟡 P1级 - 二方库最佳实践 **【蚂蚁专属·推荐】**

### 1. 【推荐】依赖管理
- 使用蚂蚁统一依赖管理BOM
- 避免依赖冲突

### 2. 【推荐】API设计规范
- 接口设计遵循蚂蚁API规范
- 提供完善的Javadoc文档

## 🔍 蚂蚁专属检查清单

### 代码审查时必须检查：
- [ ] **GAV规范**：是否符合蚂蚁GAV命名规范
- [ ] **版本管理**：版本号是否符合语义化规范
- [ ] **依赖管理**：是否使用蚂蚁统一依赖管理
- [ ] **API设计**：接口设计是否符合蚂蚁规范

### 配置检查：
```xml
<!-- 蚂蚁专属配置检查 -->
<dependencyManagement>
    <dependencies>
        <!-- 蚂蚁统一BOM -->
        <dependency>
            <groupId>com.antgroup</groupId>
            <artifactId>ant-bom</artifactId>
            <version>${ant.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

### 常见蚂蚁专属陷阱：

| 陷阱类型 | 错误示例 | 蚂蚁专属风险 |
|----------|----------|--------------|
| GAV不规范 | 使用非蚂蚁groupId | 无法统一管理 |
| 版本混乱 | 使用SNAPSHOT版本 | 生产环境不稳定 |
| 依赖冲突 | 未使用统一BOM | 版本冲突问题 |

---

**⚠️ 重要提醒**：以上规范仅适用于蚂蚁集团内部二方库管理，其他组织不适用这些特殊要求。