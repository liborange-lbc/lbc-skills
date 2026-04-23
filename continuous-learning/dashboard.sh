#!/bin/bash
# Generates a visual HTML dashboard for the continuous-learning knowledge compiler.
# Reads markdown/JSON from ~/.claude/learning/ and outputs dashboard.html.
# Usage: bash dashboard.sh [--open]

set -euo pipefail

LEARNING_DIR="$HOME/.claude/learning"
RULES_DIR="$HOME/.claude/rules/common/learned"
SKILLS_DIR="$HOME/.claude/skills/learned"
OUTPUT="$LEARNING_DIR/dashboard.html"
INDEX_FILE="$LEARNING_DIR/.index.json"

# ── Collect data ──────────────────────────────────────────────

# Count L1 sessions
L1_COUNT=0
L1_ITEMS="[]"
if [ -d "$LEARNING_DIR/sessions" ]; then
  shopt -s nullglob 2>/dev/null || true
  L1_FILES=("$LEARNING_DIR/sessions"/*.md)
  shopt -u nullglob 2>/dev/null || true
  if [ ${#L1_FILES[@]} -gt 0 ] && [ -f "${L1_FILES[0]}" ]; then
    L1_COUNT=${#L1_FILES[@]}
    L1_ITEMS=$(python3 -c "
import os, json, re, sys

sessions = []
session_dir = '$LEARNING_DIR/sessions'
for f in sorted(os.listdir(session_dir)):
    if not f.endswith('.md'): continue
    path = os.path.join(session_dir, f)
    with open(path) as fh:
        content = fh.read()
    # Extract frontmatter
    date = re.search(r'date:\s*(.+)', content)
    domain = re.search(r'domain:\s*(.+)', content)
    # Extract title from first H1 (supports both English and Chinese)
    title = re.search(r'^#\s+(?:Session|会话)[：:]\s*(.+)', content, re.MULTILINE)
    # Extract key insight
    insight_match = re.search(r'## (?:Key Insight|核心洞察)\s*\n(.+)', content)
    sessions.append({
        'file': f,
        'date': date.group(1).strip() if date else f[:10],
        'domain': domain.group(1).strip() if domain else 'unknown',
        'title': title.group(1).strip() if title else f.replace('.md',''),
        'insight': insight_match.group(1).strip() if insight_match else ''
    })
print(json.dumps(sessions[-30:]))  # Last 30
" 2>/dev/null || echo "[]")
  fi
fi

# Count & read L2 patterns
L2_COUNT=0
L2_ITEMS="[]"
if [ -d "$LEARNING_DIR/patterns" ]; then
  shopt -s nullglob 2>/dev/null || true
  L2_FILES=("$LEARNING_DIR/patterns"/*.md)
  shopt -u nullglob 2>/dev/null || true
  if [ ${#L2_FILES[@]} -gt 0 ] && [ -f "${L2_FILES[0]}" ]; then
    L2_COUNT=${#L2_FILES[@]}
    L2_ITEMS=$(python3 -c "
import os, json, re

patterns = []
pattern_dir = '$LEARNING_DIR/patterns'
for f in sorted(os.listdir(pattern_dir)):
    if not f.endswith('.md'): continue
    path = os.path.join(pattern_dir, f)
    with open(path) as fh:
        content = fh.read()
    confidence = re.search(r'confidence:\s*(\w+)', content)
    evidence = re.search(r'evidence_count:\s*(\d+)', content)
    status = re.search(r'status:\s*(\w+)', content)
    domain = re.search(r'domain:\s*(.+)', content)
    title = re.search(r'^#\s+(?:Pattern|模式)[：:]\s*(.+)', content, re.MULTILINE)
    observation = re.search(r'## (?:Observation|观察)\s*\n(.+)', content)
    patterns.append({
        'file': f,
        'title': title.group(1).strip() if title else f.replace('.md',''),
        'confidence': confidence.group(1).strip() if confidence else 'low',
        'evidence': int(evidence.group(1)) if evidence else 0,
        'status': status.group(1).strip() if status else 'active',
        'domain': domain.group(1).strip() if domain else 'unknown',
        'observation': observation.group(1).strip() if observation else ''
    })
print(json.dumps(patterns))
" 2>/dev/null || echo "[]")
  fi
fi

# Count L3 rules
L3_RULE_COUNT=0
L3_RULES="[]"
if [ -d "$RULES_DIR" ]; then
  shopt -s nullglob 2>/dev/null || true
  L3_RULE_FILES=("$RULES_DIR"/*.md)
  shopt -u nullglob 2>/dev/null || true
  if [ ${#L3_RULE_FILES[@]} -gt 0 ] && [ -f "${L3_RULE_FILES[0]}" ]; then
    L3_RULE_COUNT=${#L3_RULE_FILES[@]}
    L3_RULES=$(python3 -c "
import os, json, re

rules = []
rules_dir = '$RULES_DIR'
for f in sorted(os.listdir(rules_dir)):
    if not f.endswith('.md'): continue
    path = os.path.join(rules_dir, f)
    with open(path) as fh:
        content = fh.read()
    title = re.search(r'^#\s+(.+)', content, re.MULTILINE)
    source = re.search(r'(?:Auto-promoted from pattern|自动晋升自模式)\s*\[(.+?)\]', content)
    rules.append({
        'file': f,
        'title': title.group(1).strip() if title else f.replace('.md',''),
        'source': source.group(1).strip() if source else ''
    })
print(json.dumps(rules))
" 2>/dev/null || echo "[]")
  fi
fi

# Count L3 skills
L3_SKILL_COUNT=0
L3_SKILLS="[]"
if [ -d "$SKILLS_DIR" ]; then
  shopt -s nullglob 2>/dev/null || true
  L3_SKILL_FILES=("$SKILLS_DIR"/*.md)
  shopt -u nullglob 2>/dev/null || true
  if [ ${#L3_SKILL_FILES[@]} -gt 0 ] && [ -f "${L3_SKILL_FILES[0]}" ]; then
    L3_SKILL_COUNT=${#L3_SKILL_FILES[@]}
    L3_SKILLS=$(python3 -c "
import os, json, re

skills = []
skills_dir = '$SKILLS_DIR'
for f in sorted(os.listdir(skills_dir)):
    if not f.endswith('.md'): continue
    path = os.path.join(skills_dir, f)
    with open(path) as fh:
        content = fh.read()
    title = re.search(r'^#\s+(.+)', content, re.MULTILINE)
    desc = re.search(r'description:\s*(.+)', content)
    skills.append({
        'file': f,
        'title': title.group(1).strip() if title else f.replace('.md',''),
        'description': desc.group(1).strip() if desc else ''
    })
print(json.dumps(skills))
" 2>/dev/null || echo "[]")
  fi
fi

# Read session log
SESSION_LOG="[]"
if [ -f "$LEARNING_DIR/session-log.jsonl" ]; then
  SESSION_LOG=$(tail -50 "$LEARNING_DIR/session-log.jsonl" | python3 -c "
import sys, json
lines = []
for line in sys.stdin:
    line = line.strip()
    if line:
        try: lines.append(json.loads(line))
        except: pass
print(json.dumps(lines))
" 2>/dev/null || echo "[]")
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
L3_TOTAL=$((L3_RULE_COUNT + L3_SKILL_COUNT))

# ── Generate HTML ─────────────────────────────────────────────

cat > "$OUTPUT" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Knowledge Compiler Dashboard</title>
<style>
  :root {
    --bg: #0d1117; --surface: #161b22; --border: #30363d;
    --text: #e6edf3; --text-dim: #8b949e; --text-muted: #484f58;
    --blue: #58a6ff; --green: #3fb950; --yellow: #d29922;
    --orange: #db6d28; --red: #f85149; --purple: #bc8cff;
    --cyan: #39d2c0;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    background: var(--bg); color: var(--text); padding: 24px; min-height: 100vh;
  }

  /* ── Header ── */
  .header {
    text-align: center; margin-bottom: 32px;
    border-bottom: 1px solid var(--border); padding-bottom: 24px;
  }
  .header h1 { font-size: 28px; font-weight: 700; letter-spacing: -0.5px; }
  .header h1 span { color: var(--cyan); }
  .header .subtitle { color: var(--text-dim); margin-top: 4px; font-size: 14px; }
  .header .generated { color: var(--text-muted); font-size: 12px; margin-top: 8px; }

  /* ── Stats Bar ── */
  .stats-bar {
    display: flex; gap: 16px; justify-content: center;
    margin-bottom: 32px; flex-wrap: wrap;
  }
  .stat-card {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 12px; padding: 16px 24px; text-align: center;
    min-width: 140px; position: relative; overflow: hidden;
  }
  .stat-card::before {
    content: ''; position: absolute; top: 0; left: 0; right: 0; height: 3px;
  }
  .stat-card.l1::before { background: var(--blue); }
  .stat-card.l2::before { background: var(--yellow); }
  .stat-card.l3::before { background: var(--green); }
  .stat-card .number { font-size: 36px; font-weight: 700; line-height: 1; }
  .stat-card.l1 .number { color: var(--blue); }
  .stat-card.l2 .number { color: var(--yellow); }
  .stat-card.l3 .number { color: var(--green); }
  .stat-card .label { color: var(--text-dim); font-size: 13px; margin-top: 4px; }

  /* ── Pyramid ── */
  .pyramid-section { margin-bottom: 40px; }
  .pyramid-section h2 {
    font-size: 18px; margin-bottom: 16px; display: flex;
    align-items: center; gap: 8px;
  }
  .pyramid {
    display: flex; flex-direction: column; align-items: center; gap: 0;
    margin: 0 auto; max-width: 900px;
  }
  .pyramid-layer {
    position: relative; padding: 20px 24px; border-radius: 8px;
    border: 1px solid var(--border); background: var(--surface);
  }
  .pyramid-layer.l3 { width: 50%; min-width: 320px; }
  .pyramid-layer.l2 { width: 72%; min-width: 420px; }
  .pyramid-layer.l1 { width: 94%; min-width: 520px; }

  .pyramid-arrow {
    display: flex; flex-direction: column; align-items: center;
    color: var(--text-muted); padding: 6px 0; font-size: 12px;
  }
  .pyramid-arrow .arrow-icon { font-size: 20px; line-height: 1; }
  .pyramid-arrow .arrow-label { font-size: 11px; color: var(--text-dim); }

  .layer-header {
    display: flex; justify-content: space-between; align-items: center;
    margin-bottom: 12px;
  }
  .layer-tag {
    font-size: 11px; font-weight: 600; padding: 2px 8px;
    border-radius: 10px; text-transform: uppercase; letter-spacing: 0.5px;
  }
  .l3 .layer-tag { background: rgba(63,185,80,0.15); color: var(--green); }
  .l2 .layer-tag { background: rgba(210,153,34,0.15); color: var(--yellow); }
  .l1 .layer-tag { background: rgba(88,166,255,0.15); color: var(--blue); }
  .layer-title { font-size: 15px; font-weight: 600; }
  .layer-count { color: var(--text-dim); font-size: 13px; }

  /* ── Items inside layers ── */
  .layer-items { display: flex; flex-direction: column; gap: 8px; }
  .layer-item {
    background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06);
    border-radius: 6px; padding: 10px 14px; font-size: 13px;
    display: flex; justify-content: space-between; align-items: center;
  }
  .layer-item .item-title { font-weight: 500; flex: 1; }
  .layer-item .item-meta { color: var(--text-dim); font-size: 12px; margin-left: 12px; white-space: nowrap; }

  /* Confidence badges */
  .badge {
    font-size: 11px; padding: 1px 8px; border-radius: 8px;
    font-weight: 600; display: inline-block;
  }
  .badge.low { background: rgba(88,166,255,0.15); color: var(--blue); }
  .badge.medium { background: rgba(210,153,34,0.15); color: var(--yellow); }
  .badge.high { background: rgba(63,185,80,0.15); color: var(--green); }
  .badge.promoted { background: rgba(188,140,255,0.15); color: var(--purple); }

  .empty-state {
    color: var(--text-muted); font-size: 13px; font-style: italic;
    text-align: center; padding: 12px;
  }

  /* ── Flow diagram ── */
  .flow-section { margin-bottom: 40px; }
  .flow-section h2 { font-size: 18px; margin-bottom: 16px; }
  /* ── Flow Pipeline ── */
  .flow-pipeline {
    background: var(--surface); border: 1px solid var(--border); border-radius: 12px;
    padding: 32px 20px 24px; overflow-x: auto;
  }
  .flow-legend {
    display: flex; gap: 28px; justify-content: center; margin-bottom: 24px;
    font-size: 12px; color: var(--text-dim);
  }
  .flow-legend-item { display: flex; align-items: center; gap: 6px; }
  .legend-arrow-sample {
    display: inline-flex; align-items: center; font-size: 11px; letter-spacing: -1px;
    color: var(--orange); font-weight: 700; flex-shrink: 0;
  }
  .legend-rect {
    width: 16px; height: 12px; border-radius: 4px;
    border: 2px solid var(--blue); flex-shrink: 0;
  }

  .flow-stages {
    display: flex; align-items: stretch; justify-content: center; gap: 0;
    min-width: 900px;
  }

  /* Product nodes: rounded rectangle */
  .flow-product {
    padding: 14px 14px; border-radius: 12px; text-align: center;
    min-width: 120px; max-width: 145px; display: flex; flex-direction: column;
    justify-content: center; align-items: center; flex-shrink: 0;
  }
  .flow-product.source {
    background: rgba(255,255,255,0.04); border: 2px dashed var(--text-muted);
  }
  .flow-product.source .fp-label { color: var(--text-dim); }
  .flow-product.l1 { background: rgba(88,166,255,0.08); border: 2px solid rgba(88,166,255,0.4); }
  .flow-product.l2 { background: rgba(210,153,34,0.08); border: 2px solid rgba(210,153,34,0.4); }
  .flow-product.l3 { background: rgba(63,185,80,0.08); border: 2px solid rgba(63,185,80,0.4); }
  .flow-product .fp-icon { font-size: 24px; }
  .flow-product .fp-label { font-size: 12px; font-weight: 700; margin-top: 5px; }
  .flow-product.l1 .fp-label { color: var(--blue); }
  .flow-product.l2 .fp-label { color: var(--yellow); }
  .flow-product.l3 .fp-label { color: var(--green); }
  .flow-product .fp-criteria {
    font-size: 10px; color: var(--text-dim); margin-top: 6px;
    background: rgba(255,255,255,0.04); padding: 4px 8px; border-radius: 6px;
    line-height: 1.5;
  }

  /* Action nodes: hollow wide arrow */
  .flow-action {
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    padding: 0 2px; flex-shrink: 0;
  }
  .action-arrow {
    position: relative; display: flex; align-items: center; height: 52px;
  }
  /* Arrow shaft */
  .action-arrow .shaft {
    width: 60px; height: 28px; border: 2px solid; border-right: none;
    border-radius: 4px 0 0 4px; display: flex; align-items: center;
    justify-content: center;
  }
  /* Arrow head (triangle) */
  .action-arrow .head {
    width: 0; height: 0; border-top: 26px solid transparent;
    border-bottom: 26px solid transparent; border-left: 22px solid;
  }
  /* Color variants */
  .flow-action.act-capture .shaft { border-color: var(--blue); }
  .flow-action.act-capture .head { border-left-color: var(--blue); }
  .flow-action.act-distill .shaft { border-color: var(--yellow); }
  .flow-action.act-distill .head { border-left-color: var(--yellow); }
  .flow-action.act-promote .shaft { border-color: var(--green); }
  .flow-action.act-promote .head { border-left-color: var(--green); }
  .shaft .shaft-icon { font-size: 16px; }

  .flow-action .fa-label { font-size: 11px; font-weight: 700; margin-top: 6px; }
  .flow-action.act-capture .fa-label { color: var(--blue); }
  .flow-action.act-distill .fa-label { color: var(--yellow); }
  .flow-action.act-promote .fa-label { color: var(--green); }
  .flow-action .fa-trigger {
    font-size: 9px; color: var(--text-dim); margin-top: 3px;
    background: rgba(255,255,255,0.04); padding: 3px 7px; border-radius: 5px;
    line-height: 1.5; text-align: center; max-width: 120px;
  }

  /* ── Timeline ── */
  .timeline-section { margin-bottom: 40px; }
  .timeline-section h2 { font-size: 18px; margin-bottom: 16px; }
  .timeline {
    position: relative; padding-left: 24px;
    border-left: 2px solid var(--border); margin-left: 12px;
  }
  .timeline-entry {
    position: relative; margin-bottom: 12px; padding: 8px 14px;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 8px; font-size: 13px;
  }
  .timeline-entry::before {
    content: ''; position: absolute; left: -31px; top: 14px;
    width: 10px; height: 10px; border-radius: 50%;
    border: 2px solid var(--border); background: var(--bg);
  }
  .timeline-entry.session::before { border-color: var(--blue); background: var(--blue); }
  .timeline-entry.pattern::before { border-color: var(--yellow); background: var(--yellow); }
  .timeline-entry.rule::before { border-color: var(--green); background: var(--green); }
  .timeline-date { color: var(--text-dim); font-size: 11px; }
  .timeline-title { font-weight: 500; margin-top: 2px; }
  .timeline-insight { color: var(--text-dim); font-size: 12px; margin-top: 4px; }

  /* ── Responsive ── */
  @media (max-width: 768px) {
    body { padding: 12px; }
    .pyramid-layer.l3, .pyramid-layer.l2, .pyramid-layer.l1 {
      width: 100% !important; min-width: 0 !important;
    }
    .flow-stages { flex-direction: column; align-items: center; min-width: 0; }
    .flow-action .action-arrow { transform: rotate(90deg); }
    .flow-product { max-width: none; }
  }
</style>
</head>
<body>

<div class="header">
  <h1><span>知识</span>编译器</h1>
  <div class="subtitle">三层开发者智慧管道 · 会话 → 模式 → 规则</div>
  <div class="generated" id="generated-time">生成中...</div>
</div>

<div class="stats-bar" id="stats-bar"></div>

<!-- Flow Diagram -->
<div class="flow-section">
  <h2>晋升管道 <span style="font-size:12px;color:var(--text-dim);font-weight:400">— 每次会话结束时 ①②③ 顺序执行</span></h2>
  <div class="flow-pipeline">
    <div class="flow-legend">
      <div class="flow-legend-item"><div class="legend-arrow-sample">══▷</div> 晋升动作（空心箭头）</div>
      <div class="flow-legend-item"><div class="legend-rect"></div> 晋升产物（圆角矩形）</div>
    </div>
    <div class="flow-stages">

      <!-- Source: 日常对话 -->
      <div class="flow-product source">
        <div class="fp-icon">💬</div>
        <div class="fp-label">日常对话</div>
        <div class="fp-criteria">编码、调试、设计、<br>配置、重构……</div>
      </div>

      <!-- Action: Step 1 自动捕获 -->
      <div class="flow-action act-capture">
        <div class="action-arrow">
          <div class="shaft"><span class="shaft-icon">📝</span></div>
          <div class="head"></div>
        </div>
        <div class="fa-label">① 自动捕获</div>
        <div class="fa-trigger">会话结束时执行<br>跳过条件：<5条消息<br>且无调试/纠正/新方法</div>
      </div>

      <!-- Product: L1 会话 -->
      <div class="flow-product l1">
        <div class="fp-icon">📦</div>
        <div class="fp-label">L1 会话摘要</div>
        <div class="fp-criteria">产物标准：<br>完成的工作、有效方法、<br>失败纠正、核心洞察</div>
      </div>

      <!-- Action: Step 2 自动提炼 -->
      <div class="flow-action act-distill">
        <div class="action-arrow">
          <div class="shaft"><span class="shaft-icon">🔍</span></div>
          <div class="head"></div>
        </div>
        <div class="fa-label">② 自动提炼</div>
        <div class="fa-trigger">紧接①执行：扫描全部<br>L1 文件，按领域/标签<br>聚类，≥2个则建 L2</div>
      </div>

      <!-- Product: L2 模式 -->
      <div class="flow-product l2">
        <div class="fp-icon">🧩</div>
        <div class="fp-label">L2 开发模式</div>
        <div class="fp-criteria">产物标准：<br>≥2个证据链、<br>具体观察（非笼统）、<br>适用/不适用条件</div>
      </div>

      <!-- Action: Step 3 自动晋升 -->
      <div class="flow-action act-promote">
        <div class="action-arrow">
          <div class="shaft"><span class="shaft-icon">⬆️</span></div>
          <div class="head"></div>
        </div>
        <div class="fa-label">③ 自动晋升</div>
        <div class="fa-trigger">紧接②执行：扫描全部<br>L2 文件，数证据条数<br>≥5条=high → 写入规则</div>
      </div>

      <!-- Product: L3 规则/技能 -->
      <div class="flow-product l3">
        <div class="fp-icon">⚡</div>
        <div class="fp-label">L3 规则 / 技能</div>
        <div class="fp-criteria">产物标准：<br>比L2更具体可操作、<br>写入 rules/ 或 skills/、<br>含触发条件和例外</div>
      </div>

    </div>
  </div>
</div>

<!-- Pyramid -->
<div class="pyramid-section">
  <h2>知识分层 Knowledge Layers</h2>
  <div class="pyramid" id="pyramid"></div>
</div>

<!-- Timeline -->
<div class="timeline-section">
  <h2>最近活动 Recent Activity</h2>
  <div class="timeline" id="timeline"></div>
</div>

<script>
// ── Data injected by dashboard.sh ──
HTMLEOF

# Inject data as JS variables
cat >> "$OUTPUT" << DATAEOF
const DATA = {
  generated: "$NOW",
  l1: { count: $L1_COUNT, items: $L1_ITEMS },
  l2: { count: $L2_COUNT, items: $L2_ITEMS },
  l3: { rules: $L3_RULES, skills: $L3_SKILLS, ruleCount: $L3_RULE_COUNT, skillCount: $L3_SKILL_COUNT, total: $L3_TOTAL },
  sessionLog: $SESSION_LOG
};
DATAEOF

cat >> "$OUTPUT" << 'JSEOF'

// ── Render ──
document.getElementById('generated-time').textContent =
  `生成时间：${new Date(DATA.generated).toLocaleString('zh-CN')}`;

// Stats bar
const statsBar = document.getElementById('stats-bar');
statsBar.innerHTML = `
  <div class="stat-card l1"><div class="number">${DATA.l1.count}</div><div class="label">L1 会话</div></div>
  <div class="stat-card l2"><div class="number">${DATA.l2.count}</div><div class="label">L2 模式</div></div>
  <div class="stat-card l3"><div class="number">${DATA.l3.total}</div><div class="label">L3 规则 & 技能</div></div>
`;

// Pyramid
const pyramid = document.getElementById('pyramid');

function renderItems(items, type) {
  if (!items || items.length === 0) return '<div class="empty-state">暂无数据 —— 等待知识积累</div>';
  return items.map(item => {
    if (type === 'l1') {
      return `<div class="layer-item">
        <span class="item-title">${item.title}</span>
        <span class="item-meta">${item.domain} · ${item.date}</span>
      </div>`;
    } else if (type === 'l2') {
      return `<div class="layer-item">
        <span class="item-title">${item.title}</span>
        <span class="item-meta">
          <span class="badge ${item.confidence}">${item.confidence}</span>
          ${item.evidence} 个证据 · ${item.domain}
          ${item.status === 'promoted' ? ' <span class="badge promoted">已晋升</span>' : ''}
        </span>
      </div>`;
    } else {
      return `<div class="layer-item">
        <span class="item-title">${item.title}</span>
        <span class="item-meta">${item.source || item.description || ''}</span>
      </div>`;
    }
  }).join('');
}

const l3Items = [...DATA.l3.rules.map(r => ({...r, _type: 'rule'})), ...DATA.l3.skills.map(s => ({...s, _type: 'skill'}))];

pyramid.innerHTML = `
  <div class="pyramid-layer l3">
    <div class="layer-header">
      <span><span class="layer-tag">L3</span> <span class="layer-title">规则 & 技能</span></span>
      <span class="layer-count">${DATA.l3.total} 条</span>
    </div>
    <div class="layer-items">${renderItems(l3Items, 'l3')}</div>
  </div>

  <div class="pyramid-arrow">
    <div class="arrow-label">置信度 = high → 自动晋升</div>
    <div class="arrow-icon">▲</div>
  </div>

  <div class="pyramid-layer l2">
    <div class="layer-header">
      <span><span class="layer-tag">L2</span> <span class="layer-title">开发模式</span></span>
      <span class="layer-count">${DATA.l2.count} 个模式</span>
    </div>
    <div class="layer-items">${renderItems(DATA.l2.items, 'l2')}</div>
  </div>

  <div class="pyramid-arrow">
    <div class="arrow-label">≥2 个会话聚类 → 自动提炼</div>
    <div class="arrow-icon">▲</div>
  </div>

  <div class="pyramid-layer l1">
    <div class="layer-header">
      <span><span class="layer-tag">L1</span> <span class="layer-title">会话摘要</span></span>
      <span class="layer-count">${DATA.l1.count} 个会话</span>
    </div>
    <div class="layer-items">${renderItems(DATA.l1.items.slice(-8).reverse(), 'l1')}</div>
  </div>
`;

// Timeline
const timeline = document.getElementById('timeline');
const timelineEntries = [];

DATA.l1.items.forEach(s => {
  timelineEntries.push({
    date: s.date, type: 'session',
    title: s.title, detail: s.insight || s.domain
  });
});
DATA.l2.items.forEach(p => {
  timelineEntries.push({
    date: p.file.slice(0, 10) || '—', type: 'pattern',
    title: `模式：${p.title}`, detail: `${p.confidence} · ${p.evidence} 个证据`
  });
});
DATA.l3.rules.forEach(r => {
  timelineEntries.push({
    date: '—', type: 'rule',
    title: `规则：${r.title}`, detail: `来自 ${r.source}`
  });
});

timelineEntries.sort((a, b) => b.date.localeCompare(a.date));

if (timelineEntries.length === 0) {
  timeline.innerHTML = '<div class="empty-state">暂无活动记录 —— 等待知识积累</div>';
} else {
  timeline.innerHTML = timelineEntries.slice(0, 20).map(e => `
    <div class="timeline-entry ${e.type}">
      <div class="timeline-date">${e.date}</div>
      <div class="timeline-title">${e.title}</div>
      ${e.detail ? `<div class="timeline-insight">${e.detail}</div>` : ''}
    </div>
  `).join('');
}
</script>
</body>
</html>
JSEOF

echo "[Dashboard] Generated: $OUTPUT"

# Auto-open if --open flag
if [[ "${1:-}" == "--open" ]]; then
  open "$OUTPUT" 2>/dev/null || xdg-open "$OUTPUT" 2>/dev/null || echo "Open manually: $OUTPUT"
fi
