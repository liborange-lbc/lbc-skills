# 商业化计量接入编码规约 **【数科专属】**

> 数科项目涉及计费计量相关功能时需遵循本规约。与【蚂蚁专属】中间件规范可同时用于同一项目，按实际技术栈选用。

---

## 1. 依赖与配置管理

### 1.1 Maven 依赖

**【强制】** 必须使用计量官方提供的 SDK 依赖，且版本号不得低于文档推荐的最低版本，以确保接口兼容性。

**正例**：

```xml
<dependency>
    <groupId>com.antgroup.antchain.openapi</groupId>
    <artifactId>openapi-oms</artifactId>
    <version>1.1.1</version>
</dependency>
```

### 1.2 密钥管理

**【强制】** `AccessKeyId` 与 `AccessKeySecret` 严禁硬编码在代码中，必须通过配置中心或环境变量注入。

**【强制】** 生产环境网关域名必须配置为 `openapi-cn-shanghai-nf.antchain.antgroup.com`，严禁使用测试域名。

### 1.3 计量域配置

**【强制】** `domain_code`（计量域）与 `field_code`（计量项）必须在调用前已在计量后台完成配置，严禁使用未注册的编码进行推送。

---

## 2. 请求参数构造规范

### 2.1 业务单号 (biz_no)

**【强制】** `biz_no` 必须保证全局唯一，长度控制在 32–64 字符之间。

**【强制】** `biz_no` 仅支持数字、字母、下划线，**严禁包含中文**或特殊符号。

**【强制】** 在重试场景下，必须保持 `biz_no` 不变，以确保接口的幂等性。

**正例**：

```java
// 使用业务类型 + 唯一 ID 生成
String bizNo = "propertyChain_" + UUID.randomUUID().toString().replace("-", "");
request.setBizNo(bizNo);
```

**反例**：

```java
// 包含中文，可能导致校验失败
request.setBizNo("计量单号_20231001_001");

// 重试时生成了新的 UUID，导致重复计费
request.setBizNo(UUID.randomUUID().toString());
```

### 2.2 时间格式与时区

**【强制】** 所有时间字段（`start_time`, `end_time`, `push_time`）必须遵循 ISO8601 格式，且必须带时区标识（如 `Z` 或 `+08`）。

**【强制】** 时间转换工具类必须线程安全，严禁在多线程环境下复用非线程安全的 `SimpleDateFormat`。

**正例**：

```java
// 使用官方工具或线程安全的 DateTimeFormatter
String timeStr = DateUtils.convertToStringWithTZ(new Date());
request.setStartTime(timeStr);
```

**【强制】** `time_zone` 字段需与时间字符串中的时区保持一致，国内业务默认填写 `GMT+8`。

### 2.3 计量数据值 (meter_data)

**【强制】** `meter_data` 中的 `field_value` 必须转换为 **String** 类型，即使原始数据是数字。

**【强制】** `meter_data` 的 Key (`field_code`) 必须与后台配置完全一致，区分大小写。

**正例**：

```java
MeterField field = new MeterField();
field.setFieldCode("REQUEST_AMT");
field.setFieldValue(String.valueOf(100)); // 显式转为字符串
```

---

## 3. 接口调用逻辑

### 3.1 数据推送 (meterdata.push)

**【强制】** 每次产生计量数据后，应立即调用 `antcloud.oms.meterdata.push` 接口，避免本地堆积导致数据丢失。

**【推荐】** 对于高并发场景，建议采用异步队列方式推送，但需保证队列数据的持久化，防止进程重启丢失。

### 3.2 节点标示 (nodeflag.push)

**【强制】** 仅在**周期推送**场景下调用 `antcloud.oms.nodeflag.push`，单次上报场景**严禁**调用。

**【强制】** 调用 `nodeflag.push` 前，必须确认该时间窗口 `[start_time, end_time]` 内的所有 `meterdata` 均已推送成功。

**【强制】** `nodeflag` 请求中的 `domain_code`, `start_time`, `end_time`, `node_id` 必须与该窗口内 `meterdata` 推送的参数完全一致。

**正例**：

```java
// 1. 推送完该小时所有数据后
// 2. 调用打标接口，告知计费侧可以出账
PushNodeflagRequest nodeFlagRequest = new PushNodeflagRequest();
nodeFlagRequest.setReadyFlag(Boolean.TRUE);
nodeFlagRequest.setStartTime(windowStart); // 与 meterdata 中的时间一致
nodeFlagRequest.setEndTime(windowEnd);     // 与 meterdata 中的时间一致
client.pushNodeflag(nodeFlagRequest);
```

---

## 4. 异常处理与幂等性

### 4.1 响应码处理

**【强制】** 必须检查 `result_code`，仅当值为 `OK` 或特定幂等错误码时视为成功。

**【强制】** 遇到 `BIZ_NO_ILLEGAL` 错误码，应视为**推送成功**，无需重试，记录日志即可。

**【强制】** 遇到 `METER_ID_ILLEGAL` 错误码，需检查计量域主键配置或视为重复推送，无需重试。

**正例**：

```java
if (!"OK".equals(response.getResultCode())) {
    if ("BIZ_NO_ILLEGAL".equals(response.getResultCode())) {
        // 重复上报，视为成功，不重试
        log.warn("Meter data already pushed, bizNo: {}", bizNo);
    } else {
        // 其他错误（如网络超时、系统错误），需要重试
        throw new RetryableException("Meter push failed", response.getResultCode());
    }
}
```

**反例**：

```java
// 遇到任何非 OK 都抛出异常重试，会导致 BIZ_NO_ILLEGAL 场景下的无限重试或日志污染
if (!"OK".equals(response.getResultCode())) {
    throw new RuntimeException("Push failed");
}
```

### 4.2 重试机制

**【推荐】** 对于非业务逻辑错误（如网络超时、`PUSH_TIME_OUT`），应实现指数退避重试机制。

**【强制】** 重试时严禁修改 `biz_no`，否则会导致同一笔业务被重复计费。

---

## 5. 数据一致性检查

### 5.1 时间窗口闭区间

**【强制】** `start_time` 与 `end_time` 为闭区间。周期推送时，相邻窗口的时间点需无缝衔接，避免漏计或重叠。

**说明**：例如 10:00-11:00 的数据推送完成后，下一窗口应为 11:00-12:00。

### 5.2 资源标识

**【强制】** `resource_id` 必须保持稳定性，同一业务资源在不同时间推送时必须使用相同的 `resource_id`，否则可能导致计费侧无法聚合数据。

---

## 检查清单

计量接入代码 Review 时关注：

- [ ] Maven 依赖版本是否符合官方要求
- [ ] AK/SK 是否硬编码
- [ ] `biz_no` 是否全局唯一且不含中文
- [ ] 重试逻辑中 `biz_no` 是否保持不变
- [ ] 时间格式是否为 ISO8601 且带时区
- [ ] `meter_data` 的值是否已转为 String
- [ ] 周期推送是否在完成数据推送后调用了 `nodeflag.push`
- [ ] `nodeflag` 的时间窗口是否与 `meterdata` 一致
- [ ] 是否正确处理了 `BIZ_NO_ILLEGAL` 幂等错误码
- [ ] 单次上报场景是否错误调用了 `nodeflag` 接口