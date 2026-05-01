/**
 * app.js - 流水线可视化 Dashboard 主逻辑
 * 轮询、SVG 渲染、交互、增量 DOM 更新
 */

// ============ 全局状态 ============
const state = {
  data: null,
  prevData: null,
  selectedPhase: null,
  selectedFile: null,
  fileViewerOpen: false,
  fileViewerContent: null,
};

// ============ 常量配置 ============
const POLL_INTERVAL = 5000;
const NODE_WIDTH = 120;
const NODE_HEIGHT = 60;
const NODE_SPACING = 160;
const SVG_WIDTH = 1400;
const SVG_HEIGHT = 400;
const BASE_Y = 180;

// 状态颜色映射
const STATUS_COLORS = {
  pending:   { fill: '#F5F5F5', stroke: '#E0E0E0' },
  running:   { fill: '#E3F2FD', stroke: '#2196F3' },
  pass:      { fill: '#E8F5E9', stroke: '#4CAF50' },
  fail:      { fill: '#FFEBEE', stroke: '#F44336' },
  iterating: { fill: '#FFF3E0', stroke: '#FF9800' },
};

// ============ 工具函数 ============
function formatDuration(seconds) {
  if (seconds == null) return '';
  if (seconds < 60) return `${seconds}s`;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  if (m < 60) return s > 0 ? `${m}m${s}s` : `${m}m`;
  const h = Math.floor(m / 60);
  const rm = m % 60;
  return rm > 0 ? `${h}h${rm}m` : `${h}h`;
}

// 设计理念模式静态数据
const DESIGN_PRINCIPLES_MAP = {
  P1: { label: '需求驱动全流程', desc: '需求清单贯穿8 Phase，每个阶段围绕需求条目执行，确保全链路可追踪' },
  P2: { label: 'GitNexus赋能', desc: '代码分析基于知识图谱，自动生成代码阅读报告与关联摘要' },
  P3: { label: '文档驱动交接', desc: 'Phase间通过结构化文档传递上下文，减少信息损耗' },
  P4: { label: 'Resume优于新建', desc: '修正循环复用同一Agent实例，保留上下文续做，避免重建开销' },
  P5: { label: '扩展优于硬编码', desc: '通过EXTENSION_DOCS挂载领域知识，无需修改代码即可扩展能力' },
  P6: { label: '经验库累积', desc: '修正过程中沉淀可复用模式到经验库，持续提升后续迭代效率' },
  P7: { label: 'GitNexus赋能', desc: '利用知识图谱进行影响面分析，精确评估变更范围' },
  P8: { label: '主Agent纯调度', desc: '主Agent不执行具体任务，只负责决策和路由分发' },
};

// Phase 角色说明（用于设计理念模式预填充）
const PHASE_ROLES = {
  P1: { role: '需求分析师', input: '用户原始需求', output: '需求清单.md' },
  P2: { role: '代码阅读Agent', input: '代码仓库', output: '代码阅读报告+知识摘要' },
  P3: { role: '架构师Agent', input: '需求清单+代码报告', output: '系分文档+追踪矩阵' },
  P4: { role: '评审Agent', input: '系分文档', output: '系分文档(已审)' },
  P5: { role: '编码Agent', input: '系分文档(已审)', output: '代码实现' },
  P6: { role: 'CR Agent', input: '代码', output: '代码(已审)' },
  P7: { role: '测试Agent', input: '代码(已审)', output: '测试报告' },
  P8: { role: '主调度Agent', input: '测试报告', output: '交付报告' },
};

// ============ 初始化 ============
document.addEventListener('DOMContentLoaded', async () => {
  // 先加载需求目录列表
  await loadDirs();

  // 首次立即请求
  fetchStatus();
  startPolling();

  // 绑定事件
  document.getElementById('overlay').addEventListener('click', closeFileViewer);
  document.getElementById('file-viewer-close').addEventListener('click', closeFileViewer);
  document.getElementById('req-selector').addEventListener('change', onReqChange);
});

// ============ 轮询逻辑 ============
let pollTimer = null;

function startPolling() {
  pollTimer = setInterval(fetchStatus, POLL_INTERVAL);
}

async function fetchStatus() {
  try {
    const selector = document.getElementById('req-selector');
    const dir = selector.value;
    const url = dir ? `/api/status?dir=${encodeURIComponent(dir)}` : '/api/status';
    const res = await fetch(url);
    if (!res.ok) return;
    const data = await res.json();
    if (data.error) return;
    updateState(data);
  } catch (e) {
    // 网络错误静默处理，下次轮询重试
  }
}

function updateState(newData) {
  state.prevData = state.data;
  state.data = newData;
  render();
}

// ============ 渲染入口 ============
function render() {
  const data = state.data;
  if (!data) return;

  // 更新顶部信息
  document.getElementById('project-name').textContent =
    `${data.requirement_name || 'ai-coding-agents'} 流水线`;
  document.getElementById('last-scan').textContent =
    `最后扫描: ${data.last_scan_time || '--'}`;

  // 判断是否为设计理念模式（无数据或全部 pending）
  const isDesignMode = !data.phases ||
    data.phases.every(p => p.status === 'pending');

  renderPipelineGraph(data.phases, isDesignMode);

  // 设计理念模式：自动展示所有 Phase 的完整信息
  if (isDesignMode) {
    renderDesignModePanel(data.phases);
  } else if (state.selectedPhase) {
    const phase = data.phases.find(p => p.id === state.selectedPhase);
    if (phase) renderDetailPanel(phase);
  }
}

// ============ SVG 流程图渲染 ============
function renderPipelineGraph(phases, isDesignMode) {
  const svg = document.getElementById('pipeline-svg');
  const prev = state.prevData;

  // 首次渲染或结构变化时重建 SVG
  if (!prev || !prev.phases) {
    svg.innerHTML = buildPipelineSVG(phases, isDesignMode);
    bindNodeEvents();
    return;
  }

  // 增量更新：仅更新状态变化的节点
  let needsRebuild = false;
  for (let i = 0; i < phases.length; i++) {
    const curr = phases[i];
    const prevPhase = prev.phases[i];
    if (!prevPhase || curr.status !== prevPhase.status) {
      needsRebuild = true;
      break;
    }
    // 并行 Phase 检查子 Agent 状态
    if (curr.parallel && curr.agents) {
      for (let j = 0; j < curr.agents.length; j++) {
        if (!prevPhase.agents || !prevPhase.agents[j] ||
            curr.agents[j].status !== prevPhase.agents[j].status) {
          needsRebuild = true;
          break;
        }
      }
    }
    if (needsRebuild) break;
  }

  if (needsRebuild) {
    svg.innerHTML = buildPipelineSVG(phases, isDesignMode);
    bindNodeEvents();
  }
}

function buildPipelineSVG(phases, isDesignMode) {
  let svg = '';

  // 设计理念模式横幅
  if (isDesignMode) {
    svg += `<text x="${SVG_WIDTH / 2}" y="30" text-anchor="middle" font-size="13" fill="#0969da">当前无运行数据，展示设计理念模式</text>`;
  }

  // 绘制连线和标注
  svg += buildEdges(phases);

  // 绘制修正循环箭头（P4→P3, P6→P5）
  svg += buildIterationArrows(phases);

  // 绘制节点
  for (let i = 0; i < phases.length; i++) {
    const phase = phases[i];
    const x = 60 + i * NODE_SPACING;

    if (phase.parallel && phase.agents) {
      // 并行节点：上中下三个小节点
      svg += buildParallelNodes(phase, x, isDesignMode);
    } else {
      // 单节点
      svg += buildSingleNode(phase, x, BASE_Y, isDesignMode);
    }
  }

  return svg;
}

function buildSingleNode(phase, x, y, isDesignMode) {
  const colors = STATUS_COLORS[phase.status] || STATUS_COLORS.pending;
  const principle = isDesignMode ? DESIGN_PRINCIPLES_MAP[phase.id] : null;
  const tooltip = principle ? `${principle.label} — ${principle.desc}` : '';

  const dur = formatDuration(phase.duration_seconds);
  const bottomText = dur || phase.agent || '';

  return `
    <g class="phase-node status-${phase.status}" data-phase="${phase.id}" transform="translate(${x}, ${y})">
      <rect x="0" y="0" width="${NODE_WIDTH}" height="${NODE_HEIGHT}"
            fill="${colors.fill}" stroke="${colors.stroke}"/>
      <text class="node-id" x="${NODE_WIDTH / 2}" y="16" text-anchor="middle">${phase.id}</text>
      <text class="node-name" x="${NODE_WIDTH / 2}" y="34" text-anchor="middle">${phase.name}</text>
      <text class="node-agent" x="${NODE_WIDTH / 2}" y="50" text-anchor="middle">${bottomText}</text>
      ${isDesignMode && tooltip ? `<title>${tooltip}</title>` : ''}
    </g>
  `;
}

function buildParallelNodes(phase, x, isDesignMode) {
  let svg = '';
  const offsets = [-70, 0, 70];
  const smallH = 50;
  const smallW = 110;

  // 主节点（虚线框）
  const phaseDur = formatDuration(phase.duration_seconds);
  const phaseDurLabel = phaseDur ? ` (${phaseDur})` : '';
  svg += `<g class="phase-node status-${phase.status}" data-phase="${phase.id}" transform="translate(${x - 5}, ${BASE_Y - 85})">
    <rect x="0" y="0" width="${NODE_WIDTH + 10}" height="230"
          fill="none" stroke="#d0d7de" stroke-dasharray="4" rx="8" ry="8"/>
    <text class="node-id" x="${(NODE_WIDTH + 10) / 2}" y="-5" text-anchor="middle" fill="#57606a">${phase.id} ${phase.name}${phaseDurLabel}</text>
  </g>`;

  // 子 Reviewer 节点
  phase.agents.forEach((agent, idx) => {
    const nodeY = BASE_Y + offsets[idx] - 20;
    const colors = STATUS_COLORS[agent.status] || STATUS_COLORS.pending;
    const label = agent.perspective.length > 5 ? agent.perspective.slice(0, 5) + '..' : agent.perspective;

    const agentDur = formatDuration(agent.duration_seconds);
    const verdictLine = agentDur
      ? `${agent.verdict || agent.status} ${agentDur}`
      : (agent.verdict || agent.status);

    svg += `
      <g class="phase-node status-${agent.status}" data-phase="${phase.id}" transform="translate(${x}, ${nodeY})">
        <rect x="0" y="0" width="${smallW}" height="${smallH}"
              fill="${colors.fill}" stroke="${colors.stroke}"/>
        <text class="node-name" x="${smallW / 2}" y="20" text-anchor="middle" font-size="11">${label}</text>
        <text class="node-agent" x="${smallW / 2}" y="36" text-anchor="middle" font-size="9">${verdictLine}</text>
      </g>
    `;
  });

  return svg;
}

function buildEdges(phases) {
  let svg = '';
  for (let i = 0; i < phases.length - 1; i++) {
    const x1 = 60 + i * NODE_SPACING + NODE_WIDTH;
    const x2 = 60 + (i + 1) * NODE_SPACING;
    const y = BASE_Y + NODE_HEIGHT / 2;

    // 判断是否为活跃连线（左侧或右侧 phase 为 running/iterating）
    const leftStatus = phases[i].status;
    const rightStatus = phases[i + 1].status;
    const isActive = leftStatus === 'running' || leftStatus === 'iterating' ||
                     rightStatus === 'running' || rightStatus === 'iterating';
    const pathClass = isActive ? 'edge-path edge-path-active' : 'edge-path';

    // 连线
    svg += `<path class="${pathClass}" d="M ${x1} ${y} L ${x2} ${y}"/>`;
    // 箭头
    svg += `<polygon class="edge-arrow" points="${x2 - 6},${y - 4} ${x2},${y} ${x2 - 6},${y + 4}"/>`;
  }
  return svg;
}

function buildIterationArrows(phases) {
  let svg = '';

  // P4 修正循环 → 回到 P3
  const p4 = phases.find(p => p.id === 'P4');
  if (p4 && (p4.status === 'iterating' || p4.status === 'fail')) {
    const x4 = 60 + 3 * NODE_SPACING + NODE_WIDTH / 2;
    const x3 = 60 + 2 * NODE_SPACING + NODE_WIDTH / 2;
    const y = BASE_Y + NODE_HEIGHT + 30;
    const loopClass = p4.status === 'iterating' ? 'edge-path edge-path-loop-active' : 'edge-path edge-path-loop';
    const iterCount = p4.iteration_count || 1;
    svg += `<path class="${loopClass}" d="M ${x4} ${BASE_Y + NODE_HEIGHT} Q ${x4} ${y} ${(x3 + x4) / 2} ${y} T ${x3} ${BASE_Y + NODE_HEIGHT}" fill="none"/>`;
    svg += `<text class="edge-label" x="${(x3 + x4) / 2}" y="${y + 14}" fill="#FF9800">x${iterCount}</text>`;
  }

  // P6 修正循环 → 回到 P5
  const p6 = phases.find(p => p.id === 'P6');
  if (p6 && (p6.status === 'iterating' || p6.status === 'fail')) {
    const x6 = 60 + 5 * NODE_SPACING + NODE_WIDTH / 2;
    const x5 = 60 + 4 * NODE_SPACING + NODE_WIDTH / 2;
    const y = BASE_Y + NODE_HEIGHT + 30;
    const loopClass = p6.status === 'iterating' ? 'edge-path edge-path-loop-active' : 'edge-path edge-path-loop';
    const iterCount = p6.iteration_count || 1;
    svg += `<path class="${loopClass}" d="M ${x6} ${BASE_Y + NODE_HEIGHT} Q ${x6} ${y} ${(x5 + x6) / 2} ${y} T ${x5} ${BASE_Y + NODE_HEIGHT}" fill="none"/>`;
    svg += `<text class="edge-label" x="${(x5 + x6) / 2}" y="${y + 14}" fill="#FF9800">x${iterCount}</text>`;
  }

  return svg;
}

function bindNodeEvents() {
  document.querySelectorAll('.phase-node').forEach(node => {
    node.addEventListener('click', (e) => {
      const phaseId = node.getAttribute('data-phase');
      if (phaseId) {
        state.selectedPhase = phaseId;
        const phase = state.data.phases.find(p => p.id === phaseId);
        if (phase) renderDetailPanel(phase);
      }
    });
  });
}

// ============ Agent 详情面板 ============
function renderDetailPanel(phase) {
  const panel = document.getElementById('detail-panel');
  panel.classList.remove('empty');

  if (phase.parallel && phase.agents) {
    panel.innerHTML = buildParallelDetail(phase);
  } else {
    panel.innerHTML = buildSingleDetail(phase);
  }

  // 绑定文件链接事件
  panel.querySelectorAll('.file-link').forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const path = link.getAttribute('data-path');
      if (path) openFileViewer(path);
    });
  });
}

function buildSingleDetail(phase) {
  const inputFiles = (phase.input_files || []).map(f => {
    const path = buildFilePath(f);
    return `<li><a class="file-link" data-path="${path}" href="#">${f}</a></li>`;
  }).join('');

  const outputFiles = (phase.output_files || []).map(f => {
    const path = buildFilePath(f);
    return `<li><a class="file-link" data-path="${path}" href="#">${f}</a></li>`;
  }).join('');

  const principles = (phase.design_principles || []).map(p =>
    `<span class="principle-tag">${p}</span>`
  ).join('');

  // 设计理念完整说明
  const principleDetail = DESIGN_PRINCIPLES_MAP[phase.id]
    ? `<div class="principle-desc"><strong>${DESIGN_PRINCIPLES_MAP[phase.id].label}:</strong> ${DESIGN_PRINCIPLES_MAP[phase.id].desc}</div>`
    : '';

  const logLink = phase.log_file
    ? `<a class="file-link" data-path="${state.data.requirement_dir}/${phase.log_file}" href="#">${phase.log_file}</a>`
    : '--';

  return `
    <div class="detail-header">
      <h3>${phase.id} ${phase.name} - ${phase.agent || ''}</h3>
      <span class="status-badge ${phase.status}">${phase.status}</span>
    </div>
    <div class="detail-grid">
      <div class="detail-section">
        <h4>输入文件</h4>
        <ul>${inputFiles || '<li>--</li>'}</ul>
      </div>
      <div class="detail-section">
        <h4>输出文件</h4>
        <ul>${outputFiles || '<li>--</li>'}</ul>
      </div>
    </div>
    <div class="detail-summary">
      <strong>日志:</strong> ${logLink}<br>
      <strong>耗时:</strong> ${formatDuration(phase.duration_seconds) || '--'}<br>
      ${buildSpansHtml(phase.spans)}
      <strong>摘要:</strong> ${phase.summary || '无'}
    </div>
    <div class="detail-principles">${principles}${principleDetail}</div>
  `;
}

function buildParallelDetail(phase) {
  // 三个 Reviewer 并排
  const reviewerCards = (phase.agents || []).map(agent => {
    const stats = agent.stats || {};
    return `
      <div class="reviewer-card">
        <h5>${agent.perspective}</h5>
        <span class="status-badge ${agent.status}">${agent.verdict || agent.status}</span>
        <div class="reviewer-duration">${formatDuration(agent.duration_seconds) || '--'}</div>
        <div class="reviewer-stats">
          <span>C:${stats.critical || 0}</span>
          <span>H:${stats.high || 0}</span>
          <span>M:${stats.medium || 0}</span>
          <span>L:${stats.low || 0}</span>
        </div>
        ${buildSpansHtml(agent.spans)}
        <div style="margin-top:6px">
          <a class="file-link" data-path="${state.data.requirement_dir}/${agent.log_file}" href="#">${agent.log_file}</a>
        </div>
      </div>
    `;
  }).join('');

  // 迭代信息
  const iterations = (phase.iterations || []).map(it =>
    `第${it.round}轮: ${it.result}`
  ).join(' | ');

  const principles = (phase.design_principles || []).map(p =>
    `<span class="principle-tag">${p}</span>`
  ).join('');

  const principleDetail = DESIGN_PRINCIPLES_MAP[phase.id]
    ? `<div class="principle-desc"><strong>${DESIGN_PRINCIPLES_MAP[phase.id].label}:</strong> ${DESIGN_PRINCIPLES_MAP[phase.id].desc}</div>`
    : '';

  return `
    <div class="detail-header">
      <h3>${phase.id} ${phase.name}</h3>
      <span class="status-badge ${phase.status}">${phase.status}</span>
      <span style="font-size:12px;color:#57606a">迭代: ${phase.iteration_count || 0}/${phase.max_iteration || 3}</span>
    </div>
    <div class="reviewers-grid">${reviewerCards}</div>
    ${iterations ? `<div class="iteration-info">修正循环: ${iterations}</div>` : ''}
    <div class="detail-principles" style="margin-top:12px">${principles}${principleDetail}</div>
  `;
}

function buildSpansHtml(spans) {
  if (!spans || spans.length <= 1) return '';
  const items = spans.map(s => {
    const dur = formatDuration(s.duration_seconds);
    const endLabel = s.end ? s.end.slice(11, 16) : '进行中';
    return `<span class="span-tag">${s.label}: ${dur} (${s.start.slice(11, 16)}→${endLabel})</span>`;
  }).join(' ');
  return `<div class="spans-row"><strong>执行明细:</strong> ${items}</div>`;
}

function buildFilePath(filename) {
  if (!state.data) return '';
  const dir = state.data.requirement_dir || '';
  // log 文件已包含 log/ 前缀
  if (filename.startsWith('log/')) {
    return `${dir}/${filename}`;
  }
  return `${dir}/${filename}`;
}

// ============ 设计理念模式面板 ============
function renderDesignModePanel(phases) {
  const panel = document.getElementById('detail-panel');
  panel.classList.remove('empty');

  const phaseIds = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'];
  const cards = phaseIds.map(id => {
    const phase = phases.find(p => p.id === id);
    const role = PHASE_ROLES[id] || {};
    const principle = DESIGN_PRINCIPLES_MAP[id] || {};
    const name = phase ? phase.name : id;

    return `
      <div class="design-card">
        <div class="design-card-header"><strong>${id}</strong> ${name}</div>
        <div class="design-card-body">
          <div><span class="design-label">角色:</span> ${role.role || '--'}</div>
          <div><span class="design-label">输入:</span> ${role.input || '--'}</div>
          <div><span class="design-label">输出:</span> ${role.output || '--'}</div>
          <div class="principle-desc"><span class="design-label">设计理念:</span> <strong>${principle.label || '--'}</strong> — ${principle.desc || ''}</div>
        </div>
      </div>
    `;
  }).join('');

  panel.innerHTML = `
    <div class="detail-header">
      <h3>设计理念总览</h3>
      <span style="font-size:12px;color:#57606a">无运行数据时自动展示</span>
    </div>
    <div class="design-grid">${cards}</div>
  `;
}

// ============ 文件查看器 ============
async function openFileViewer(path) {
  state.fileViewerOpen = true;
  document.getElementById('file-viewer').classList.add('open');
  document.getElementById('overlay').classList.add('visible');
  document.getElementById('file-viewer-path').textContent = path;
  document.getElementById('file-viewer-content').innerHTML = '<p>加载中...</p>';

  try {
    const res = await fetch(`/api/file?path=${encodeURIComponent(path)}`);
    const data = await res.json();
    if (data.error) {
      document.getElementById('file-viewer-content').innerHTML = `<p style="color:#C62828">错误: ${data.error}</p>`;
      return;
    }
    const html = renderMarkdown(data.content);
    document.getElementById('file-viewer-content').innerHTML = html;
  } catch (e) {
    document.getElementById('file-viewer-content').innerHTML = `<p style="color:#C62828">加载失败</p>`;
  }
}

function closeFileViewer() {
  state.fileViewerOpen = false;
  document.getElementById('file-viewer').classList.remove('open');
  document.getElementById('overlay').classList.remove('visible');
}

// ============ 需求选择器 ============
const DIR_STATUS_ICONS = { running: '🔄', completed: '✅', idle: '⏳' };

async function loadDirs() {
  try {
    const res = await fetch('/api/dirs');
    if (!res.ok) return;
    const { dirs } = await res.json();
    const selector = document.getElementById('req-selector');
    selector.innerHTML = '';
    if (dirs.length === 0) {
      selector.innerHTML = '<option value="">无需求目录</option>';
      return;
    }
    dirs.forEach((d, i) => {
      const opt = document.createElement('option');
      opt.value = d.path;
      opt.textContent = `${DIR_STATUS_ICONS[d.status] || ''} ${d.name}`;
      if (i === 0) opt.selected = true;
      selector.appendChild(opt);
    });
  } catch (e) {
    // 静默失败，使用默认
  }
}

function onReqChange() {
  // 切换需求目录后立即刷新
  state.data = null;
  state.prevData = null;
  state.selectedPhase = null;
  fetchStatus();
}
