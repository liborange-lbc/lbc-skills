# 数科网关接入规范 **【数科专属】**

> **数科网关** 暴露 OpenAPI 的服务端设计与实现。与 **【蚂蚁专属】** 中间件规范可同时用于同一项目，按实际技术栈选用。

## 说明：业务字段 vs 公共参数

**【强制】** OpenAPI 文档中的**业务自定义**请求/响应字段不得使用公共参数名、保留参数名或与网关/SDK 约定冲突的名称（如 `req_msg_id`、`result_code` 等）。

**说明**：`req_msg_id`、`access_key`、`sign` 等属于网关层标准公共请求参数，由 SDK/网关自动携带；产品侧接口定义里写的是**业务入参/出参**，二者命名空间不同——业务字段禁止占用公共/保留名，避免契约冲突与解析歧义。

---

## 1. 接口设计规范

### 1.1 请求入参 **【强制】**

- 命名：**小写下划线**（snake_case）；禁用语言关键字。
- 业务字段不得使用公共/保留入参名，例如：`req_msg_id`、`product_instance_id`、`tenant` 等（完整列表见第 3 节表格与保留列表）。
- 示例接近真实值；描述文案中禁止出现 `*/`（避免注释/文档截断问题）。
- 尽量**平铺**参数，减少深层嵌套结构体。
- 结构稳定时避免用 `String` 承载整段 JSON（应用明确字段或结构化类型）。

### 1.2 响应回参 **【强制】**

- 命名：**小写下划线**；禁用语言关键字。
- 业务字段不得使用公共/保留回参名，例如：`result_code`、`result_msg`、`secrets`、`request_id` 等。
- 语义约定：成功时统一 `result_code=OK`；非 OK 为业务或网关异常码；`result_msg` 承载异常说明（具体由网关与产品约定，业务自定义字段勿与之重名）。
- 尽量平铺；结构稳定时避免 `String` 装 JSON。

### 1.3 业务结果码 **【强制】**

- 命名：`大写下划线`，如 `BIZ_ERROR`、`NOT_ALLOWED`。
- **禁止**在业务码枚举中再定义 `OK`；成功统一用 `OK`（表示调用成功且业务成功）。
- 仅定义**业务异常码**；与网关内部异常码区分（见第 5 节）。

### 1.4 SDK 依赖 **【推荐】**

Provider 侧 API 依赖示例（`ProductCode`、`version` 按产品替换）：

```xml
<dependency>
    <groupId>cn.com.antcloud.api</groupId>
    <artifactId>antcloud-api-provider-${ProductCode}</artifactId>
    <version>${version}</version>
</dependency>
```

---

## 2. 公共请求参数

### 2.1 标准公共请求参数（11 个）

| 公共参数名 | 说明 | 必传 | 示例值 | SDK 支持 |
|---|---|:---:|---|---|
| req_msg_id | 请求 ID，32 位纯字母 uuid | 是 | b20167e21a8d4cc2b5f1022d24f43815 | 自动生成 |
| req_time | 请求时间（15 min 内），ISO8601 GMT | 是 | 2021-02-03T13:43:47Z | 自动生成 |
| method | OpenApi 名，4–5 段点分 | 是 | antcloud.iam.accessor.current.get | 自动生成 |
| version | OpenApi 版本 | 是 | 1.0 | 自动生成 |
| base_sdk_version | SDK 核心版本 | 否 | TeaSDK-2.0 | 自动生成 |
| sdk_version | SDK 发行版本 | 否 | 3.12.0 | 自动生成 |
| access_key | 用户 AccessKey | 是 | ACxxxxxxxxxxxxxx | Client 配置 |
| sign_type | 签名方式，默认 HmacSHA1 | 是 | HmacSHA1 | Client 配置 |
| sign | 签名结果 | 是 | zP5lAkGZXo1N/e5sIsHDpiCZpNw= | 自动生成 |
| security_token | STS 模式 token | 否 |  | Client 配置 |
| auth_token | OAUTH 模式 token | 否 |  | 请求对象独立设置 |

### 2.2 非标公共请求参数（不推荐）

| 公共参数名 | 说明 | 必传 | 示例值 | SDK 支持 |
|---|---|:---:|---|---|
| product_instance_id | 集群 ID，用于路由 | 否 | demo-api-test | 请求对象独立设置 |
| region_name | 多 Region 使用 | 否 | CN-HANGZHOU-FINANCE | 网关侧 SDK 不再支持 |
| gw_test_url | 指定 TR 调用地址 | 否 | 11.168.138.120:12200 | 无 SDK 支持 |

### 2.3 保留公共请求参数（易引起冲突）

```
product_access_code | pop_system_param | api_stage | charset
invoker | op_sys_param | internal_api | ant_unique_id
target | aliyun_user | req_time_zone | project
status | request_id | format | real_source
```

---

## 3. 公共响应参数

### 3.1 标准公共响应参数（≥3 个）

| 公共参数名 | 说明 | 示例值 | SDK 支持 |
|---|---|---|---|
| req_msg_id | 请求 ID，与入参一致 | b20167e21a8d4cc2b5f1022d24f43815 | 支持 |
| result_code | 结果码，`OK` 表示成功 | OK | 支持 |
| result_msg | 异常信息 | Access denied by IAM | 支持 |

### 3.2 非标公共响应参数

| 公共参数名 | 说明 | 示例值 | SDK 支持 |
|---|---|---|---|
| secrets | 回参加密字段 | ["xxx","yyy","zzz"] | 网关侧 SDK 暂不生成 |

### 3.3 保留公共响应参数（易引起冲突）

```
sign | code | message | success
request_id | msg | http_status_code
```

---

## 4. 结果码规范

### 4.1 标准成功结果码

| 结果码 | 含义 | 详细信息 |
|---|---|---|
| OK | 成功 | 调用成功且业务成功 |

### 4.2 网关内部异常码

| 结果码 | 含义 | 提示信息 |
|---|---|---|
| UNKNOW_ERROR | 业务未知错误 | 无 |
| GW_UNKNOW_ERROR | 网关未知错误 | 无 |
| INTERNAL_ERROR | 系统内部异常 | 无 |
| INVALID_ACCESS_KEY | AK 错误 | 检查 AK 是否跨云错配 |
| INVALID_SIGNATURE | 签名错误 | AK 无效或不存在 |
| ACCESS_DENIED | 无权调用 | 无 |
| MISSING_PARAMETER | 参数缺失 | 提示缺失字段 |
| INVALID_PARAMETER | 参数无效 | 提示字段及原因 |
| API_NOT_EXIST | API 不存在 | 提示 OpenApi 名称 |
| API_UNAVAILABLE | API 不可用 | 服务有损发布 |
| OVER_RATE_LIMIT | 额度超限 | 提示资源及限额 |
| INVOKE_TIMEOUT | 调用超时 | 结果未知 |
| INVOKE_OVERFLOW | 频率超限 | 提示频率限制 |
| TENANT_NOT_EXIST | 租户不存在 | 提示租户 ID |
| WORKSPACE_NOT_EXIST | 工作空间不存在 | 提示名称 |
| NO_ROUTE_INFO | 路由信息缺失 | 检查集群 ID 或地域 |
| WRITE_LIST_DENIED | 白名单校验失败 | 内部接口需配置白名单 |
| INVALID_AUTH_SCOPE | 授权范围非法 | 无 |
| INVALID_AUTH_TOKEN | AuthToken 非法 | 无 |
| DEFAULT_SERVICE_NOT_EXIST | 默认路由缺失 | 检查路由配置 |
| BAD_PROVIDER_RESPONSE | 下游格式错误 | 下游未按固定格式返回 |
| PROVIDER_SERVICE_TIMEOUT | 下游超时 | 联系产品方 |
| PROVIDER_CONNECT_CLOSED | 下游链接关闭 | 联系产品方 |
| CLUSTER_ACCESS_KEY_NOT_EXIST | 路由失败 | 检查路由配置、域名、product_instance_id |
