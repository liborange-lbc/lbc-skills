#!/usr/bin/env bash
# 向执行日志追加一条 Agent 事件记录
# 时间戳由本脚本生成，确保格式一致（YYYY-MM-DD HH:MM:SS）
#
# 用法:
#   bash log-event.sh <执行日志路径> <Phase> <Agent名称> <agentId> <事件> [备注]
#
# 示例:
#   bash log-event.sh .ai-coding/20260502-用户注册/log/执行日志.md P5 P5-编码工程师-catalog af123 启动 "编码实现"
#   bash log-event.sh .ai-coding/20260502-用户注册/log/执行日志.md P5 P5-编码工程师-catalog af123 完成 "R01-R03 编码完成"

set -euo pipefail

LOG_FILE="${1:?用法: log-event.sh <日志路径> <Phase> <Agent名称> <agentId> <事件> [备注]}"
PHASE="${2:?缺少 Phase 参数}"
AGENT_NAME="${3:?缺少 Agent名称 参数}"
AGENT_ID="${4:?缺少 agentId 参数}"
EVENT="${5:?缺少 事件 参数}"
NOTE="${6:-}"

# === 事件枚举校验 ===
VALID_EVENTS="启动 完成 PASS FAIL Resume 降级新建"
if ! echo "$VALID_EVENTS" | grep -qw "$EVENT"; then
  echo "错误: 事件 '$EVENT' 不合法。允许值: $VALID_EVENTS" >&2
  exit 1
fi

# === 时间戳（精确到秒） ===
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# === 计算序号（当前最大序号 + 1） ===
if [ -f "$LOG_FILE" ]; then
  LAST_SEQ=$(grep -E '^\| *[0-9]+ *\|' "$LOG_FILE" | tail -1 | awk -F'|' '{gsub(/^ *| *$/,"",$2); print $2}' 2>/dev/null || echo "0")
  # 如果提取失败或为空，默认 0
  if ! [[ "$LAST_SEQ" =~ ^[0-9]+$ ]]; then
    LAST_SEQ=0
  fi
else
  echo "错误: 日志文件不存在: $LOG_FILE" >&2
  exit 1
fi

SEQ=$((LAST_SEQ + 1))

# === 追加记录 ===
echo "| ${SEQ} | ${TIMESTAMP} | ${PHASE} | ${AGENT_NAME} | ${AGENT_ID} | ${EVENT} | ${NOTE} |" >> "$LOG_FILE"

# === 输出确认（供主Agent读取） ===
echo "logged: #${SEQ} ${TIMESTAMP} ${PHASE} ${AGENT_NAME} ${EVENT}"
