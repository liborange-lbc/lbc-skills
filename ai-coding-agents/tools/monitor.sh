#!/usr/bin/env bash
# 流水线执行监控 — tmux 分屏实时查看子Agent日志
#
# 用法:
#   bash monitor.sh <需求目录>
#
# 示例:
#   bash monitor.sh .ai-coding/20260502-用户注册
#
# 布局:
#   ┌──────────────────────────┬──────────────────────┐
#   │  执行日志（全局状态）       │  当前 Phase 日志       │
#   │  tail -f 执行日志.md      │  tail -f phase*.md    │
#   ├──────────────────────────┼──────────────────────┤
#   │  编排计划 / 评审报告       │  文件变更监控           │
#   │  tail -f phase5-编排*.md  │  fswatch / inotify    │
#   └──────────────────────────┴──────────────────────┘
#
# 快捷键:
#   Ctrl+B d  — 退出监控（后台保留）
#   Ctrl+B [  — 滚动查看历史
#   Ctrl+B n  — 切换窗口

set -euo pipefail

REQ_DIR="${1:?用法: monitor.sh <需求目录路径>}"
LOG_DIR="${REQ_DIR}/log"
SESSION="ai-coding-monitor"

# 检查 tmux
if ! command -v tmux &>/dev/null; then
  echo "错误: 需要安装 tmux (brew install tmux)" >&2
  exit 1
fi

# 检查需求目录
if [ ! -d "$REQ_DIR" ]; then
  echo "错误: 需求目录不存在: $REQ_DIR" >&2
  exit 1
fi

# 确保 log 目录存在
mkdir -p "$LOG_DIR"

# 确保执行日志存在（避免 tail -f 报错）
touch "$LOG_DIR/执行日志.md"

# 杀掉已有同名 session
tmux kill-session -t "$SESSION" 2>/dev/null || true

# === 创建 tmux session ===

# 窗口 1: 全局监控
tmux new-session -d -s "$SESSION" -n "全局" -x 200 -y 50

# 左上: 执行日志（全局 Agent 事件流）
tmux send-keys -t "$SESSION:全局" "echo '=== 执行日志 — Agent 事件流 ===' && tail -f '$LOG_DIR/执行日志.md' 2>/dev/null || (echo '等待执行日志创建...' && while [ ! -f '$LOG_DIR/执行日志.md' ]; do sleep 1; done && tail -f '$LOG_DIR/执行日志.md')" C-m

# 右上: 最新 phase 日志（自动跟踪最新写入的 phase 文件）
tmux split-window -h -t "$SESSION:全局"
tmux send-keys -t "$SESSION:全局.1" "echo '=== Phase 日志 — 最新活跃 ===' && while true; do LATEST=\$(ls -t '$LOG_DIR'/phase*.md 2>/dev/null | head -1); if [ -n \"\$LATEST\" ]; then echo \"▶ 跟踪: \$LATEST\"; tail -f \"\$LATEST\" & TAIL_PID=\$!; PREV=\"\$LATEST\"; while true; do sleep 2; NEW=\$(ls -t '$LOG_DIR'/phase*.md 2>/dev/null | head -1); if [ \"\$NEW\" != \"\$PREV\" ] && [ -n \"\$NEW\" ]; then kill \$TAIL_PID 2>/dev/null; echo ''; echo \"▶ 切换到: \$NEW\"; tail -f \"\$NEW\" & TAIL_PID=\$!; PREV=\"\$NEW\"; fi; done; else echo '等待 phase 日志创建...'; sleep 2; fi; done" C-m

# 左下: 编排计划 / 评审报告
tmux split-window -v -t "$SESSION:全局.0"
tmux send-keys -t "$SESSION:全局.2" "echo '=== 编排计划 & 评审报告 ===' && while true; do for f in '$LOG_DIR'/phase5-编排计划.md '$LOG_DIR'/phase4-评审-*.md '$LOG_DIR'/phase6-CR-*.md; do if [ -f \"\$f\" ]; then echo ''; echo \"━━━ \$(basename \$f) ━━━\"; tail -20 \"\$f\"; fi; done; sleep 5; done" C-m

# 右下: 文件变更监控（实时显示哪些文件被创建/修改）
tmux split-window -v -t "$SESSION:全局.1"
if command -v fswatch &>/dev/null; then
  tmux send-keys -t "$SESSION:全局.3" "echo '=== 文件变更监控 (fswatch) ===' && fswatch -r '$REQ_DIR' --event Created --event Updated --event Renamed 2>/dev/null | while read f; do echo \"\$(date '+%H:%M:%S') \$(basename \$f)\"; done" C-m
else
  tmux send-keys -t "$SESSION:全局.3" "echo '=== 文件变更监控 (poll) ===' && echo '提示: 安装 fswatch 可获得实时通知 (brew install fswatch)' && while true; do echo \"--- \$(date '+%H:%M:%S') ---\"; ls -lt '$REQ_DIR'/*.md '$LOG_DIR'/*.md 2>/dev/null | head -8 | awk '{print \$6,\$7,\$8,\$9}'; sleep 3; done" C-m
fi

# 窗口 2: 并行 coder 监控（按需切换）
tmux new-window -t "$SESSION" -n "编码"
tmux send-keys -t "$SESSION:编码" "echo '=== 并行 Coder 日志 ===' && echo '如有多个 coder，自动分屏显示各模块日志' && echo '' && while true; do CODER_LOGS=(\$(ls '$LOG_DIR'/phase5-编码-*.md 2>/dev/null)); if [ \${#CODER_LOGS[@]} -gt 0 ]; then echo \"发现 \${#CODER_LOGS[@]} 个 coder 日志:\"; for f in \"\${CODER_LOGS[@]}\"; do echo \"  - \$(basename \$f)\"; done; echo ''; echo '跟踪所有 coder 日志:'; tail -f '$LOG_DIR'/phase5-编码-*.md; break; else SINGLE='$LOG_DIR/phase5-编码.md'; if [ -f \"\$SINGLE\" ]; then echo '单 coder 模式'; tail -f \"\$SINGLE\"; break; fi; echo '等待编码日志创建...'; sleep 3; fi; done" C-m

# 选择第一个窗口
tmux select-window -t "$SESSION:全局"

echo "监控已启动: tmux session '$SESSION'"
echo ""
echo "  连接: tmux attach -t $SESSION"
echo "  退出: Ctrl+B d（后台保留）"
echo "  切换窗口: Ctrl+B n（全局 ↔ 编码）"
echo "  滚动: Ctrl+B [（q 退出滚动）"
echo "  关闭: tmux kill-session -t $SESSION"

# 自动 attach
tmux attach -t "$SESSION"
