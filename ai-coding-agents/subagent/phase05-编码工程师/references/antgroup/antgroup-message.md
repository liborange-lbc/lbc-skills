# 消息中间件规范 **【蚂蚁专属】**

> ⚠️ **蚂蚁集团架构特殊要求**：本规范仅适用于蚂蚁集团MsgBroker/ANTQ消息中间件项目

## 🔴 P0级 - 消息处理规范 **【蚂蚁专属·强制】**

### 1. 【强制】事务消息处理 **【蚂蚁专属·强制】**

**规范要求**：使用事务消息时，必须正确处理半消息状态，确保最终一致性。

**蚂蚁专属原因**：金融级系统要求严格的数据一致性。

**正确做法**：
```java
// ✅ 正确：事务消息处理
TransactionMQProducer producer = new TransactionMQProducer("producer_group");
producer.setTransactionListener(new TransactionListener() {
    @Override
    public LocalTransactionState executeLocalTransaction(Message msg, Object arg) {
        try {
            // 1. 执行本地事务
            boolean success = executeBusinessLogic(msg, arg);
            return success ? LocalTransactionState.COMMIT_MESSAGE 
                          : LocalTransactionState.ROLLBACK_MESSAGE;
        } catch (Exception e) {
            return LocalTransactionState.UNKNOW;
        }
    }

    @Override
    public LocalTransactionState checkLocalTransaction(MessageExt msg) {
        // 2. 检查本地事务状态
        boolean committed = checkBusinessStatus(msg);
        return committed ? LocalTransactionState.COMMIT_MESSAGE 
                        : LocalTransactionState.ROLLBACK_MESSAGE;
    }
});
```

### 2. 【强制】幂等设计 **【蚂蚁专属·强制】**

**规范要求**：所有消息消费必须实现幂等处理，防止重复消费。

**蚂蚁专属原因**：消息可能重复投递，必须保证业务幂等性。

**正确做法**：
```java
// ✅ 正确：幂等消费
@MessageListener(topic = "order_topic", consumerGroup = "order_consumer")
public class OrderMessageListener implements MessageListener {
    
    @Override
    public ConsumeConcurrentlyStatus consumeMessage(List<MessageExt> msgs, 
                                                   ConsumeConcurrentlyContext context) {
        for (MessageExt msg : msgs) {
            String msgId = msg.getMsgId();
            
            // 1. 检查是否已处理过
            if (isMessageProcessed(msgId)) {
                continue; // 已处理，跳过
            }
            
            // 2. 处理业务逻辑
            processBusinessLogic(msg);
            
            // 3. 记录已处理状态
            markMessageProcessed(msgId);
        }
        return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
    }
}
```

### 3. 【强制】GroupId命名规范 **【蚂蚁专属·强制】**

**规范要求**：消费者GroupId必须遵循统一命名规范。

**命名格式**：`{业务域}.{应用名}.{功能}.{环境}`

**正确示例**：
```
# ✅ 正确命名示例
payment.order-service.create-order.dev
user.user-service.update-profile.prod
```

**错误示例**：
```
# ❌ 错误命名示例
order-consumer  # 缺少业务域和环境标识
group1          # 无意义命名
```

### 4. 【强制】流控设置 **【蚂蚁专属·强制】**

**规范要求**：必须配置合理的流控参数，防止消息积压。

**正确配置**：
```java
// ✅ 正确：流控配置
DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("group_name");
consumer.setConsumeMessageBatchMaxSize(32);  // 批量消费大小
consumer.setConsumeConcurrentlyMaxSpan(2000); // 并发消费最大跨度
consumer.setPullBatchSize(32);               // 拉取批量大小
consumer.setConsumeTimeout(15);              // 消费超时时间（分钟）
```

## 🟡 P1级 - 消息最佳实践 **【蚂蚁专属·推荐】**

### 1. 【推荐】消息Key设计
- 使用业务唯一标识作为消息Key
- 便于消息查询和幂等判断

### 2. 【推荐】死信队列配置
- 配置死信队列处理失败消息
- 设置合理的重试次数和间隔

### 3. 【推荐】监控告警
- 配置消息积压监控
- 设置消费延迟告警

## 🔍 蚂蚁专属检查清单

### 代码审查时必须检查：
- [ ] **事务消息**：是否正确处理半消息状态
- [ ] **幂等设计**：是否实现了消息幂等消费
- [ ] **GroupId命名**：是否符合蚂蚁命名规范
- [ ] **流控配置**：是否配置了合理的流控参数
- [ ] **死信处理**：是否配置了死信队列

### 配置检查：
```properties
# 蚂蚁专属配置检查
# 消费者GroupId格式检查
consumer.group=payment.order-service.create-order.prod

# 流控参数检查
consumer.pullBatchSize=32
consumer.consumeTimeout=15
consumer.consumeMessageBatchMaxSize=32
```

### 常见蚂蚁专属陷阱：

| 陷阱类型 | 错误示例 | 蚂蚁专属风险 |
|----------|----------|--------------|
| 无幂等设计 | 重复消费导致业务重复执行 | 数据重复、资金损失 |
| GroupId不规范 | 无法识别业务来源 | 运维困难、问题定位困难 |
| 无流控配置 | 消息积压、系统崩溃 | 服务不可用 |
| 事务消息错误 | 数据不一致 | 金融级数据错误 |

---

**⚠️ 重要提醒**：以上规范仅适用于蚂蚁集团MsgBroker/ANTQ消息中间件，其他消息系统不适用这些特殊要求。