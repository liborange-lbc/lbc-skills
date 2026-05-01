## 判定：PASS

## 统计
- CRITICAL: 0
- HIGH: 0
- MEDIUM: 2
- LOW: 2

## 问题列表

### MEDIUM-1: API 错误消息直接插入 innerHTML（XSS）
**位置**: `app.js` line 499，`openFileViewer()` 函数
**代码**:
```js
document.getElementById('file-viewer-content').innerHTML =
  `<p style="color:#C62828">错误: ${data.error}</p>`;
```
**描述**: `data.error` 来自 `/api/file` 接口响应，未经转义直接插入 innerHTML。若后端返回恶意内容（如 `<img src=x onerror=...>`），将触发 XSS。
**风险面**: 内部 Dashboard，需后端被攻破或配置错误才可利用，实际威胁较低。
**建议**: 用 `textContent` 赋值，或通过 `escapeHtml()` 转义后再插入 innerHTML。

---

### MEDIUM-2: 详情面板动态数据未转义插入 innerHTML
**位置**: `app.js` `buildSingleDetail()`（line 374–395）、`buildParallelDetail()`（line 431–440）
**涉及字段**: `phase.id`、`phase.name`、`phase.agent`、`phase.summary`、`agent.perspective`、`agent.verdict`、`it.result`
**描述**: 上述字段均来自 `/api/status` 返回的 JSON，通过模板字符串直接插入 `panel.innerHTML`，无 HTML 实体转义。若 status 数据文件被篡改，可注入任意 HTML/JS。
**风险面**: 攻击前提是本地文件系统写入权限，威胁面受限。
**建议**: 统一封装 `escapeHtml(str)` 工具函数，对所有 API 来源字符串调用后再插入 innerHTML；或改用 DOM API（`createElement` + `textContent`）构建节点。

---

### LOW-1: SVG innerHTML 中 API 字段未转义
**位置**: `app.js` `buildSingleNode()`（line 218–220）、`buildParallelNodes()`（line 249–250）
**涉及字段**: `phase.id`、`phase.name`、`phase.agent`、`agent.perspective`、`agent.verdict`
**描述**: 字段通过模板字符串拼入 SVG 片段，再赋给 `svg.innerHTML`。SVG 内联于 HTML 文档，同受 HTML 解析器处理，存在 SVG XSS 路径（如 `<foreignObject>` 注入）。
**风险面**: Phase ID 为静态字符串（P1–P8），实际利用依赖数据文件被篡改。
**建议**: 同 MEDIUM-2，对插入 SVG 文本内容的字段调用 `escapeHtml()`。

---

### LOW-2: `iteration_count` 无类型校验直接插入 SVG
**位置**: `app.js` `buildIterationArrows()`，line 296 和 308
**代码**:
```js
const iterCount = p4.iteration_count || 1;
svg += `<text ...>x${iterCount}</text>`;
```
**描述**: `iteration_count` 未做类型检查，若 API 返回非数字字符串（如 `</text><script>alert(1)</script>`），将注入 SVG。
**风险面**: 同 LOW-1，依赖数据源被篡改。
**建议**: 加一行类型校验：`const iterCount = parseInt(p4.iteration_count, 10) || 1;`，确保插入纯数字。

---

## CSS 安全结论
`style.css` 新增的 `dash-flow`、`dash-flow-reverse`、`.edge-path-loop*` 规则**无安全风险**：
- 所有动画值为静态常量（`stroke-dashoffset: 0/24`，`opacity: 0.6/1`），无用户输入参与。
- 无 `expression()`、`url()` 外链、`@import` 等可注入向量。
- 无 CSS 注入风险。

## DoS 动画评估
- 4 条 CSS `infinite` 动画（`dash-flow` x2、`pulse` x1、`slide-in` x1），均为 GPU 合成层属性（`stroke-dashoffset`、`opacity`、`transform`），不触发 layout/paint。
- 无 `requestAnimationFrame` 或 `setInterval` 驱动的 JS 动画循环。
- **无 DoS 风险**。
