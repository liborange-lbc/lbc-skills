/**
 * md-parser.js - 零依赖 Markdown 解析器
 * 导出全局函数 renderMarkdown(text) 返回 HTML 字符串
 */

// 最大渲染行数
const MAX_RENDER_LINES = 500;

/**
 * 将 Markdown 文本转换为 HTML
 * @param {string} text - Markdown 原文
 * @returns {string} HTML 字符串
 */
function renderMarkdown(text) {
  if (!text) return '';

  const lines = text.split('\n');
  const totalLines = lines.length;
  const truncated = totalLines > MAX_RENDER_LINES;
  const processLines = truncated ? lines.slice(0, MAX_RENDER_LINES) : lines;

  const result = [];
  let inCodeBlock = false;
  let codeBlockContent = [];
  let inList = false;
  let inTable = false;
  let tableRows = [];
  let paragraphLines = [];

  const flushParagraph = () => {
    if (paragraphLines.length > 0) {
      const joined = paragraphLines.join(' ');
      result.push(`<p>${parseInline(joined)}</p>`);
      paragraphLines = [];
    }
  };

  const flushList = () => {
    if (inList) {
      result.push('</ul>');
      inList = false;
    }
  };

  const flushTable = () => {
    if (inTable && tableRows.length > 0) {
      result.push(renderTable(tableRows));
      tableRows = [];
      inTable = false;
    }
  };

  for (let i = 0; i < processLines.length; i++) {
    const line = processLines[i];

    // 代码块处理（状态机）
    if (line.trimStart().startsWith('```')) {
      if (inCodeBlock) {
        // 结束代码块 - 不做内联解析
        result.push(`<pre><code>${escapeHtml(codeBlockContent.join('\n'))}</code></pre>`);
        codeBlockContent = [];
        inCodeBlock = false;
      } else {
        // 开始代码块
        flushParagraph();
        flushList();
        flushTable();
        inCodeBlock = true;
      }
      continue;
    }

    if (inCodeBlock) {
      codeBlockContent.push(line);
      continue;
    }

    // 空行
    if (line.trim() === '') {
      flushParagraph();
      flushList();
      flushTable();
      continue;
    }

    // 标题 (1-6级)
    const headingMatch = line.match(/^(#{1,6})\s+(.+)/);
    if (headingMatch) {
      flushParagraph();
      flushList();
      flushTable();
      const level = headingMatch[1].length;
      const content = headingMatch[2];
      result.push(`<h${level}>${parseInline(content)}</h${level}>`);
      continue;
    }

    // 无序列表
    if (line.match(/^\s*[-*+]\s+/)) {
      flushParagraph();
      flushTable();
      const content = line.replace(/^\s*[-*+]\s+/, '');
      if (!inList) {
        result.push('<ul>');
        inList = true;
      }
      result.push(`<li>${parseInline(content)}</li>`);
      continue;
    }

    // 表格行
    if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
      flushParagraph();
      flushList();
      // 跳过分隔行 (|---|---|)
      if (line.match(/^\s*\|[\s\-:|]+\|\s*$/)) {
        continue;
      }
      if (!inTable) inTable = true;
      const cells = line.split('|').slice(1, -1).map(c => c.trim());
      tableRows.push(cells);
      continue;
    }

    // 普通段落行
    flushList();
    flushTable();
    paragraphLines.push(line);
  }

  // 处理剩余内容
  if (inCodeBlock) {
    result.push(`<pre><code>${escapeHtml(codeBlockContent.join('\n'))}</code></pre>`);
  }
  flushParagraph();
  flushList();
  flushTable();

  // 截断提示
  if (truncated) {
    result.push(`<div class="truncated-notice">文件过大，仅显示前 ${MAX_RENDER_LINES} 行（共 ${totalLines} 行）</div>`);
  }

  return result.join('\n');
}

/**
 * 解析内联 Markdown 语法
 */
function parseInline(text) {
  // 先转义 HTML，防止 XSS
  text = escapeHtml(text);
  // 行内代码（先处理，避免内部被其他规则干扰）
  text = text.replace(/`([^`]+)`/g, '<code>$1</code>');
  // 粗体
  text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  // 斜体
  text = text.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  // 链接（仅允许 http/https 协议，防止 javascript: URI）
  text = text.replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2" target="_blank">$1</a>');
  return text;
}

/**
 * 渲染表格
 */
function renderTable(rows) {
  if (rows.length === 0) return '';
  let html = '<table>';
  // 第一行作为表头
  html += '<thead><tr>';
  rows[0].forEach(cell => {
    html += `<th>${parseInline(cell)}</th>`;
  });
  html += '</tr></thead>';
  // 其余行
  if (rows.length > 1) {
    html += '<tbody>';
    for (let i = 1; i < rows.length; i++) {
      html += '<tr>';
      rows[i].forEach(cell => {
        html += `<td>${parseInline(cell)}</td>`;
      });
      html += '</tr>';
    }
    html += '</tbody>';
  }
  html += '</table>';
  return html;
}

/**
 * HTML 转义
 */
function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
