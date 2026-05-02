# SOFABoot Web 开发规范

## 一、SOFABoot Web 概述

SOFABoot Web 是蚂蚁集团基于 Spring MVC 的 Web 开发框架,提供了完整的 Web 服务开发能力。SOFABoot Web 完全兼容 Spring MVC,同时集成了蚂蚁内部的中间件能力。

### 核心特性

- **完全兼容 Spring MVC**: 使用方式与原生 Spring MVC 完全一致
- **内置请求追踪**: 集成 Tracer 日志,自动记录请求链路
- **请求记录**: TimerLogFilter 自动记录请求耗时和参数
- **压测打标**: 内置 LoadTestFilter 支持压测流量识别
- **MDC 上下文**: 自动初始化 MDC 上下文信息

## 二、依赖配置规范

### 2.1 SOFABoot 版本要求

确保父 pom 中的 SOFABoot 版本支持 Web 开发:

```xml
<parent>
    <groupId>com.alipay.sofa</groupId>
    <artifactId>sofaboot-alipay-dependencies</artifactId>
    <version>3.6.0+</version>  <!-- 最低3.6.0 -->
</parent>
```

### 2.2 核心依赖配置

**新应用:**
创建 SOFABoot 应用时选择 web 依赖,自动包含:

```xml
<dependency>
    <groupId>com.alipay.sofa</groupId>
    <artifactId>web-alipay-sofa-boot-starter</artifactId>
</dependency>
```

**老应用升级:**

1. 添加 web 依赖:
```xml
<dependency>
    <groupId>com.alipay.sofa</groupId>
    <artifactId>web-alipay-sofa-boot-starter</artifactId>
</dependency>
```

2. 删除原有 SOFA MVC 依赖(如有):
```xml
<!-- 删除SOFA MVC依赖 -->
<dependency>
    <groupId>com.alipay.sofa</groupId>
    <artifactId>mvc-alipay-sofa-boot-starter</artifactId>
</dependency>
<!-- 删除session依赖 -->
<dependency>
    <groupId>com.alipay.sofa.web.mvc</groupId>
    <artifactId>mvc-tair-newsession-plugin</artifactId>
</dependency>
```

> **注意**: 已使用 SOFA MVC 的应用**不推荐**替换

### 2.3 可选依赖配置

**参数校验:**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
</dependency>
```

**登录鉴权(Buservice):**
```xml
<dependency>
    <groupId>com.alipay.sofa</groupId>
    <artifactId>buservice-alipay-sofa-boot-starter</artifactId>
</dependency>
```

## 三、工程配置规范

### 3.1 配置文件目录结构

**所有 SOFABoot 应用的配置必须按照以下目录结构进行配置**:

```
bootstrap/src/main/resources/
├── application.properties          # 主配置文件(必填)
├── log4j2-spring.xml              # 日志配置文件(必填)
├── config/                        # 环境配置目录(必填)
│   ├── application.properties     # 默认环境配置
│   ├── application-default.properties  # 本地开发环境配置
│   ├── application-dev.properties      # 开发环境配置
│   ├── application-test.properties     # 测试环境配置
│   └── application-prod.properties     # 生产环境配置
└── ...
```

### 3.2 主配置文件(application.properties)

**位置**: `bootstrap/src/main/resources/config/application.properties`

**必须包含以下核心配置项**:

```properties
# SOFABoot版本标识(编译打包推荐校验)
sofa.version=SOFABoot

# 应用名称
spring.application.name=your-service-name

# 服务端口号
server.port=8080

# 日志配置(编译打包推荐校验)
logging.path=/home/admin/logs
logging.config=classpath:log4j2-spring.xml
```

### 3.3 Web 服务专属配置

**主配置文件**(`bootstrap/src/main/resources/config/application.properties`):

```properties
# 服务端口配置
server.port=8080

# 应用上下文路径
server.servlet.context-path=/your-service

# Spring MVC日期格式配置
spring.mvc-format.date=yyyy-MM-dd
spring.mvc-format.date-time=yyyy-MM-dd HH:mm:ss

# 异步请求超时时间
spring.mvc.async.request-timeout=30000

# SOFABoot Web请求记录配置
sofa.web.timer-log-filter-enable=true
sofa.web.log-timeout-threshold=3000
sofa.web.log-request-parameters-and-payload-enable=false
sofa.web.log-response-payload-enable=false
```

### 3.4 环境配置文件

**本地开发环境配置**(`config/application-default.properties`):
```properties
# 本地开发环境 Web 配置
server.port=8080
logging.path=./logs
```

**生产环境配置**(`config/application-prod.properties`):
```properties
# 生产环境 Web 配置
server.port=8080
sofa.mist.mode=prod
```

## 四、Web API 开发规范

### 4.1 REST 控制器开发规范

**【推荐】** 使用 `@RestController` 注解标识 REST API 控制器

```java
@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    /**
     * 查询用户
     */
    @GetMapping("/{userId}")
    public ApiResponse<User> getUser(@PathVariable Long userId) {
        User user = userService.findById(userId);
        return ApiResponse.success(user);
    }

    /**
     * 查询用户列表
     */
    @GetMapping
    public ApiResponse<List<User>> listUsers(
            @RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "10") int pageSize) {
        List<User> users = userService.findAll(pageNum, pageSize);
        return ApiResponse.success(users);
    }

    /**
     * 创建用户
     */
    @PostMapping
    public ApiResponse<User> createUser(@RequestBody @Valid UserDTO userDTO) {
        User user = userService.create(userDTO);
        return ApiResponse.success(user);
    }

    /**
     * 更新用户
     */
    @PutMapping("/{userId}")
    public ApiResponse<User> updateUser(
            @PathVariable Long userId,
            @RequestBody @Valid UserDTO userDTO) {
        User user = userService.update(userId, userDTO);
        return ApiResponse.success(user);
    }

    /**
     * 删除用户
     */
    @DeleteMapping("/{userId}")
    public ApiResponse<Void> deleteUser(@PathVariable Long userId) {
        userService.deleteById(userId);
        return ApiResponse.success(null);
    }
}
```

### 4.2 DTO 和参数校验规范

**【推荐】** 对请求参数进行校验,使用 JSR-303 校验注解

```java
@Data
public class UserDTO {

    @NotNull(message = "用户ID不能为空", groups = UpdateGroup.class)
    private Long id;

    @NotBlank(message = "用户名不能为空")
    @Size(min = 2, max = 20, message = "用户名长度必须在2-20之间")
    private String username;

    @Email(message = "邮箱格式不正确")
    private String email;

    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String mobile;
}

/**
 * 校验分组 - 更新操作
 */
public interface UpdateGroup {
}
```

### 4.3 统一响应包装规范

**【推荐】** 使用统一的响应包装类

```java
@Data
public class ApiResponse<T> {
    private int code;
    private String message;
    private T data;
    private long timestamp;

    public ApiResponse() {
        this.timestamp = System.currentTimeMillis();
    }

    public static <T> ApiResponse<T> success(T data) {
        ApiResponse<T> response = new ApiResponse<>();
        response.setCode(200);
        response.setMessage("success");
        response.setData(data);
        return response;
    }

    public static <T> ApiResponse<T> error(int code, String message) {
        ApiResponse<T> response = new ApiResponse<>();
        response.setCode(code);
        response.setMessage(message);
        return response;
    }

    public static <T> ApiResponse<T> error(ErrorCode errorCode) {
        return error(errorCode.getCode(), errorCode.getMessage());
    }
}
```

### 4.4 全局异常处理规范

**【推荐】** 使用 `@RestControllerAdvice` 实现全局异常处理

```java
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ApiResponse<Void> handleBusinessException(BusinessException e) {
        log.warn("业务异常: {}", e.getMessage());
        return ApiResponse.error(e.getCode(), e.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ApiResponse<Void> handleValidationException(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
            .map(FieldError::getDefaultMessage)
            .collect(Collectors.joining(", "));
        return ApiResponse.error(400, message);
    }

    @ExceptionHandler(Exception.class)
    public ApiResponse<Void> handleException(Exception e) {
        log.error("系统异常", e);
        return ApiResponse.error(500, "系统内部错误");
    }
}
```

## 五、启动和验证规范

### 5.1 验证启动日志

检查 `logs/mvc/common-default.log` 确认 Web 功能已启用:

```
'FilterRegistrationBean's:
｜---order[-10000] names[alipayTimerLogFilter]          # 请求记录
｜---order[-9000] names[alipayMDCInitFilter]             # MDC上下文
｜---order[-8000] names[alipaySofaTracerLogFilter]       # Tracer日志
｜---order[-7000] names[alipaySofaRouterFilter]          # SOFA Router
｜---order[-6000] names[alipayLoadTestFilter]            # 压测打标
```

### 5.2 API 接口测试

**测试命令:**

```bash
# 1. 健康检查
curl http://localhost:8080/your-service/health

# 2. 创建用户
curl -X POST http://localhost:8080/your-service/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "zhangsan",
    "email": "zhangsan@example.com",
    "mobile": "13800138000"
  }'

# 3. 查询用户
curl http://localhost:8080/your-service/api/users/1

# 4. 查询用户列表
curl "http://localhost:8080/your-service/api/users?pageNum=1&pageSize=10"

# 5. 更新用户
curl -X PUT http://localhost:8080/your-service/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "username": "zhangsan",
    "email": "zhangsan_new@example.com"
  }'

# 6. 删除用户
curl -X DELETE http://localhost:8080/your-service/api/users/1
```

### 5.3 检查日志输出

**请求追踪日志**(logs/sofamvc/http-trace.log):
```json
{
  "request": {
    "uri": "http://localhost:8080/your-service/api/users",
    "method": "POST",
    "headers": {...}
  },
  "response": {
    "status": 200,
    "payload": "{...}"
  },
  "timeTaken": 45
}
```

**Tracer日志**(logs/mvc/sofa-mvc-digest.log):
```
2026-03-01 10:00:00.000, ,traceId,spanId,http://localhost:8080/your-service/api/users,POST,200,0B,123B,45ms,http-nio-8080-exec-1,,
```

## 六、高级配置规范

### 6.1 CORS 跨域配置

**添加到 `config/application.properties`**:
```properties
# CORS 跨域配置
spring.mvc.cors.mappings.[/api/**].allowed-origins=*
spring.mvc.cors.mappings.[/api/**].allowed-methods=*
spring.mvc.cors.mappings.[/api/**].allowed-headers=*
```

### 6.2 文件上传配置

**添加到 `config/application.properties`**:
```properties
# 文件上传配置
spring.servlet.multipart.enabled=true
spring.servlet.multipart.max-file-size=100MB
spring.servlet.multipart.max-request-size=100MB
```

### 6.3 Tomcat 线程池配置

**添加到 `config/application.properties`**:
```properties
# Tomcat 线程池配置
server.tomcat.threads.max=200
server.tomcat.threads.min-spare=10
server.tomcat.max-connections=10000
server.tomcat.accept-count=100
```

## 七、常见问题排查

| 问题 | 排查方法 | 解决方案 |
|------|----------|----------|
| 端口冲突 | 检查`server.port`配置 | 修改端口或关闭占用进程 |
| 依赖缺失 | 检查`mvn dependency:tree` | 添加缺失依赖 |
| 启动失败 | 查看`common-error.log` | 根据错误信息修复 |
| API 404 | 检查`context-path`和路径 | 确认完整URL路径 |
| 参数校验失败 | 检查注解和分组 | 确认@Valid和校验规则 |

## 参考文档

- [SOFABoot 工程结构说明](./sofa-boot-project-structure-description.md)
- [SOFABoot 官方文档](https://yuque.antfin.com/middleware/sofaboot/guide-archetype-files)