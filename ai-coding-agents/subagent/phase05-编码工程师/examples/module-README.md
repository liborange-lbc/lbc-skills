# order-service 模块

## 职责

核心业务逻辑层，包含订单状态机、库存校验和事务编排。

## 关键类

| 类 | 职责 |
|----|------|
| OrderStateMachine | 订单状态流转（创建→支付→发货→完成/取消） |
| InventoryChecker | 库存校验与预扣 |
| OrderService | 订单 CRUD 编排 |

## 依赖

- 向下依赖：order-infrastructure（DB 访问、MQ）
- 向下依赖：order-common（DTO、错误码）
- 不得依赖：order-api