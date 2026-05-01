# Phase 6 修正循环 #1

## 修复清单

| 问题 | 级别 | 文件 | 修改描述 | 状态 |
|------|------|------|---------|------|
| R02 设计理念展示 | HIGH | app.js | 将 DESIGN_PRINCIPLES_MAP 改为 {label, desc} 结构，buildSingleDetail/buildParallelDetail 中追加 principle-desc 完整说明渲染 | ✓ |
| R11 设计理念模式 | HIGH | app.js | 新增 renderDesignModePanel 函数和 PHASE_ROLES 常量，isDesignMode 时自动渲染所有 Phase 的角色/IO/设计理念卡片 | ✓ |
| XSS 防护 | MEDIUM | md-parser.js | parseInline 入口先调用 escapeHtml 转义用户内容，链接正则限制为 https?:// 协议 | ✓ |

## 修改摘要

1. **app.js - DESIGN_PRINCIPLES_MAP 重构**: 从纯字符串改为 `{ label, desc }` 对象，SVG tooltip 和 detail-panel 均可分别取用短标签和完整说明。
2. **app.js - PHASE_ROLES 常量**: 新增各 Phase 的角色、输入、输出静态数据，供设计理念模式面板使用。
3. **app.js - renderDesignModePanel**: 新函数，当 isDesignMode 为 true 时替代空占位符，自动渲染 8 个 Phase 的卡片视图（角色、输入、输出、设计理念完整说明）。
4. **app.js - buildSingleDetail/buildParallelDetail**: 在 detail-principles 区域追加 `.principle-desc` 元素显示完整设计理念描述。
5. **md-parser.js - parseInline XSS 修复**: 在所有 Markdown 语法替换之前先 `escapeHtml(text)`，确保用户输入的 `<script>` 等标签被转义；链接正则从 `[^)]+` 收紧为 `https?://[^)]+`，阻止 `javascript:` URI 注入。
