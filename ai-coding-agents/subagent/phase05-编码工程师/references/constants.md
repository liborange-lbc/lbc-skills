# 常量定义规约

## 1. 魔法值禁止

**【强制】** 不允许任何魔法值（即未经预先定义的常量）直接出现在代码中。

**反例**：
```java
String key = "Id#taobao_" + tradeId;
cache.put(key, value);
```
**说明**：同学A定义了缓存的key，然后同学B使用缓存时少了下划线，即key是`"Id#taobao"`+tradeId，导致故障。

## 2. 常量类型规范

### 2.1 Long类型赋值

**【强制】** 在 long 或者 Long 赋值时，数值后使用大写的 L，不能是小写的 l，小写容易跟数字混淆，造成误解。

**说明**：`Long a = 2l;` 写的是数字的21，还是Long型的2?

**正例**：
```java
Long count = 1000L;
long timeout = 5000L;
```

**反例**：
```java
Long count = 1000l;  // 看起来像 10001
```

## 3. 常量类设计

### 3.1 常量归类

**【推荐】** 不要使用一个常量类维护所有常量，要按常量功能进行归类，分开维护。

**正例**：
- 缓存相关的常量放在类`CacheConsts`下
- 系统配置相关的常量放在类`SystemConfigConsts`下

**说明**：大而全的常量类，杂乱无章，使用查找功能才能定位到修改的常量，不利于理解，也不利于维护。

### 3.2 常量复用层次

**【推荐】** 常量的复用层次有五层：

| 层次 | 位置 | 说明 |
|-----|------|-----|
| 跨应用共享常量 | 二方库 `client.jar` 中的 `constant` 目录 | 多个应用共享 |
| 应用内共享常量 | 一方库子模块中的 `constant` 目录 | 单个应用内共享 |
| 子工程内共享常量 | 当前子工程的 `constant` 目录 | 子工程内共享 |
| 包内共享常量 | 当前包下单独的 `constant` 目录 | 包内共享 |
| 类内共享常量 | 类内部 `private static final` | 仅类内使用 |

**反例**：
两位开发者在两个类中分别定义了表示"是"的变量：
```java
// 类A中
public static final String YES = "yes";

// 类B中
public static final String YES = "y";

// A.YES.equals(B.YES) 预期是true，但实际返回为false，导致线上问题
```

## 4. 枚举使用

### 4.1 枚举代替常量

**【推荐】** 如果变量值仅在一个固定范围内变化用enum类型来定义。

**说明**：如果存在名称之外的延伸属性应使用enum类型。

**正例**：
```java
public enum SeasonEnum {
    SPRING(1), SUMMER(2), AUTUMN(3), WINTER(4);

    private int seq;

    SeasonEnum(int seq) {
        this.seq = seq;
    }

    public int getSeq() {
        return seq;
    }
}
```

## 5. 常量类示例

### 推荐写法

```java
// CacheConsts.java
public final class CacheConsts {
    private CacheConsts() {}

    // 缓存命名空间
    public static final String CACHE_NAMESPACE_USER = "user";
    public static final String CACHE_NAMESPACE_ORDER = "order";

    // 缓存过期时间（秒）
    public static final int CACHE_EXPIRE_SHORT = 300;      // 5分钟
    public static final int CACHE_EXPIRE_MEDIUM = 3600;    // 1小时
    public static final int CACHE_EXPIRE_LONG = 86400;     // 1天
}
```

```java
// SystemConfigConsts.java
public final class SystemConfigConsts {
    private SystemConfigConsts() {}

    // 分页默认值
    public static final int DEFAULT_PAGE_SIZE = 20;
    public static final int MAX_PAGE_SIZE = 100;

    // 超时配置
    public static final int DEFAULT_TIMEOUT_MS = 5000;
    public static final int MAX_RETRY_TIMES = 3;
}
```

## 检查清单

常量定义检查时关注：

- [ ] 没有魔法值（直接硬编码的字符串/数字）
- [ ] Long类型使用大写L后缀
- [ ] 常量按照功能归类到不同常量类
- [ ] 常量类使用正确的复用层次
- [ ] 固定范围值优先使用enum
- [ ] 常量类构造方法设为private
