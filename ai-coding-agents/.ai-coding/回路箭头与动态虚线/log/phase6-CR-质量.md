## 判定：PASS

## 统计
- CRITICAL: 0
- HIGH: 0
- MEDIUM: 2
- LOW: 3

## 问题列表

### MEDIUM

**M1 — app.js:286-313 buildIterationArrows() 中 P4/P6 处理逻辑高度重复**
两段代码结构完全相同，仅索引（3/2 vs 5/4）和 phase id（P4/P6）不同。
建议提取为辅助函数 `buildLoopArrow(phase, phaseIndex, targetIndex)`，通过参数驱动，消除 ~20 行重复。
当前可读性尚可，但后续若需支持更多回路（如 P8→P7）则维护成本高。

**M2 — style.css:124-138 .edge-path-loop / .edge-path-loop-active 使用 `!important`**
`.edge-path-loop` 和 `.edge-path-loop-active` 中 `stroke: #FF9800 !important` 使用了 `!important`。
原因是基类 `.edge-path` 已设置 `stroke: #d0d7de`，CSS 特异性相同时后定义覆盖前定义，此处 `!important` 实际并非必要——调整规则声明顺序或提高特异性（如 `.edge-path.edge-path-loop`）即可去掉 `!important`。
`!important` 会使后续覆盖更难，属于不必要的强制手段。

### LOW

**L1 — app.js:447-451 buildFilePath() 两分支逻辑等价**
```js
if (filename.startsWith('log/')) {
  return `${dir}/${filename}`;
}
return `${dir}/${filename}`;
```
两个分支返回完全相同的结果，if 块是无效代码。注释说"log 文件已包含 log/ 前缀"但并无差异处理，应直接 `return \`${dir}/${filename}\`` 或补全原本的区分逻辑。

**L2 — style.css:116-122 .edge-path 基类直接携带动画**
`.edge-path` 基类包含 `animation: dash-flow 3s linear infinite`，`.edge-path-active` 仅覆盖 animation 速度。
这意味着所有连线（包括已完成的 pass 状态节点之间）都会持续播放动画，可能产生视觉噪音。
建议将默认动画移入单独的状态类（如 `.edge-path-animating`），通过 JS 按需添加，避免非必要的持续重绘。

**L3 — style.css:75-81 `rx`/`ry` 在 CSS 中对 SVG `<rect>` 不生效**
```css
.phase-node rect {
  rx: 8;
  ry: 8;
  ...
}
```
`rx`/`ry` 是 SVG 属性，不是 CSS 属性（尽管现代浏览器的 SVG2 规范开始支持，但 Firefox < 72、Safari < 13.1 等旧版本不支持 CSS 写法）。圆角应在 SVG 的 `<rect>` 元素上用 HTML attribute 设置（`rx="8"`），而非通过 CSS 控制。当前 `buildSingleNode()` 的模板中未写 `rx`/`ry` attribute，导致节点在部分环境下无圆角。
