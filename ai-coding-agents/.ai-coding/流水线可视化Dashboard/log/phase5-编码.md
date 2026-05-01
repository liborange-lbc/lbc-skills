# Phase 5 编码日志

## 完成时间
260501 1310

## 实现清单

| 需求ID | 实现文件 | 状态 |
|--------|---------|------|
| R01 | app.js (SVG流程图 P1-P8 水平布局) | ✓ |
| R02 | app.js (P4/P6 并行分支三节点上下排列) | ✓ |
| R03 | app.js (状态颜色映射 + running脉冲动画) | ✓ |
| R04 | server.py (状态判断规则5级优先级) | ✓ |
| R05 | app.js (修正循环弧线箭头 + Resume标注) | ✓ |
| R06 | index.html + app.js (需求选择器) | ✓ |
| R07 | server.py (执行日志解析 Agent注册表+时间线) | ✓ |
| R08 | app.js (连线标注传递文档名) | ✓ |
| R09 | app.js (点击节点展开AgentDetailPanel) | ✓ |
| R10 | app.js + md-parser.js (文件查看器侧面板) | ✓ |
| R11 | app.js (设计理念模式 - 无数据时展示) | ✓ |
| R12 | app.js (5秒轮询 + 增量DOM更新) | ✓ |
| NFR01 | 全部文件 (零依赖 - 无npm/CDN) | ✓ |
| NFR02 | server.py (一条命令启动 python server.py) | ✓ |
| NFR03 | server.py (mtime缓存) + app.js (增量更新) | ✓ |
| NFR04 | 全部前端 (ES6语法 + CSS Grid/Flexbox) | ✓ |

## 技术决策

- **SVG 直接拼接**: 使用模板字符串构建 SVG innerHTML，而非逐一 createElement。理由：代码简洁，节点数少(8个)性能无差异
- **增量更新策略**: 对比前后 phases[i].status，有变化时才重建 SVG。避免 DOM diff 库引入
- **mtime 缓存**: FileCache 类按 (path, mtime) 缓存文件内容，扫描时只有文件修改才重新读取
- **Phase 配置数组**: PHASE_CONFIG 集中定义所有 Phase 的元信息，避免散落在扫描逻辑中
- **安全约束**: /api/file 接口强制路径以 `.ai-coding/` 开头且禁止 `..`，防止目录遍历
- **md-parser 全局函数**: 不用 ES module 导入（避免 CORS 问题），直接暴露 renderMarkdown 全局函数
