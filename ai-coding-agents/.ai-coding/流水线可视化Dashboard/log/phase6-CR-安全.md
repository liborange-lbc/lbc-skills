## 判定：PASS

## 统计
- CRITICAL: 0
- HIGH: 0
- MEDIUM: 3
- LOW: 2

## 问题清单

### [MEDIUM] 路径穿越防护不够严密（Unicode/编码绕过）
- 文件: server.py:426
- 描述: `_handle_file` 中对路径的检查仅做字符串匹配 `'..' in file_path`，未对 URL 编码或 Unicode 规范化后的路径再次校验。若客户端传入 `%2e%2e/` 形式，Python 的 `urlparse`/`parse_qs` 默认会解码一次，但若上游代理再解码一次则存在双重解码绕过风险。此外，校验逻辑是"先检查字符串，再拼接 Path"，而非"先拼接 Path，再用 `is_relative_to` 验证解析后的绝对路径在允许目录内"，属于不够健壮的防御方式。
- 风险: 在特定代理或双重解码场景下，攻击者可能读取 `.ai-coding/` 目录以外的任意文件。在当前单层部署（直连 Python server）环境下实际利用难度较高，但不符合最佳实践。
- 建议: 改用 `Path.resolve()` 后做 `is_relative_to` 验证：
  ```python
  full_path = (Path(self.project_root) / file_path).resolve()
  allowed_root = (Path(self.project_root) / '.ai-coding').resolve()
  if not str(full_path).startswith(str(allowed_root) + os.sep):
      self._send_json({"error": "access denied"}, 403)
      return
  ```

### [MEDIUM] /api/status 的 dir 参数未做路径边界校验
- 文件: server.py:401-413
- 描述: `_handle_status` 接收 `dir` 参数后直接拼接到 `project_root`，没有校验该参数是否包含 `..` 或超出 `.ai-coding/` 目录范围。攻击者可传入 `dir=../../../etc` 使 `LogScanner` 扫描任意目录（虽然扫描逻辑本身只读 `.md` 文件，但仍会泄露目录内容的存在性和文件名）。
- 风险: 目录遍历 + 信息泄露（通过错误响应或 `requirement_name` 字段确认路径存在性）。
- 建议: 对 `req_dir` 做与 `_handle_file` 相同级别的校验，要求以 `.ai-coding/` 开头，或用 `resolve()` + `is_relative_to` 限制在 `project_root / '.ai-coding'` 内。

### [MEDIUM] XSS — parseInline 对 Markdown 内联内容未做 HTML 转义
- 文件: md-parser.js:150-159
- 描述: `parseInline` 函数直接将 Markdown 原文中的文字内容拼接进 HTML 标签，未对特殊字符（`<`, `>`, `&`, `"`）做转义。例如，若日志文件中包含 `**<script>alert(1)</script>**`，解析后会生成 `<strong><script>alert(1)</script></strong>` 并通过 `innerHTML` 注入页面。代码块路径已正确调用 `escapeHtml`，但普通段落、标题、列表、表格均走 `parseInline` 且未转义。
- 风险: 攻击者若能控制 `.ai-coding/` 目录下的任意 `.md` 文件内容（如通过 CI/CD 注入或代码评审报告本身），可在 Dashboard 页面执行任意 JavaScript。鉴于 Dashboard 是本地开发工具且访问者即为仓库所有者，实际影响面有限，但属于 stored XSS。
- 建议: 在 `parseInline` 最开始对输入文本做全量 HTML 转义，再执行正则替换：
  ```javascript
  function parseInline(text) {
    // 先全量转义，再安全地插入已知安全的 HTML 标签
    text = escapeHtml(text);
    text = text.replace(/`([^`]+)`/g, '<code>$1</code>');
    text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    text = text.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    // 链接：href 需单独校验协议
    text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, url) => {
      const safeUrl = /^https?:\/\//.test(url) || url.startsWith('/') ? url : '#';
      return `<a href="${safeUrl}" target="_blank" rel="noopener noreferrer">${label}</a>`;
    });
    return text;
  }
  ```

### [LOW] 错误响应泄露异常堆栈信息
- 文件: server.py:414, server.py:441
- 描述: `except Exception as e: self._send_json({"error": str(e)}, 500)` 将原始异常字符串直接返回给客户端。Python 异常信息中可能包含文件系统绝对路径（如 `[Errno 13] Permission denied: '/home/user/project/.ai-coding/...'`），向调用方泄露服务器目录结构。
- 风险: 信息泄露，有助于攻击者了解服务器目录布局，辅助进一步攻击。
- 建议: 在生产环境下将详细错误记录到 stderr，仅向客户端返回通用错误消息，如 `{"error": "internal server error"}`。

### [LOW] 链接未设置 rel="noopener noreferrer"
- 文件: md-parser.js:158
- 描述: `parseInline` 生成的 `<a target="_blank">` 链接缺少 `rel="noopener noreferrer"`。
- 风险: 被打开的页面可通过 `window.opener` 访问父页面，存在轻微的 tabnabbing 风险。
- 建议: 在链接模板中添加 `rel="noopener noreferrer"`。

## 总评

代码整体安全意识良好：路径穿越做了字符串层面的防护、代码块内容已正确转义、静态文件服务也有 `..` 检查。主要问题集中在两点：①路径校验使用字符串匹配而非 `Path.resolve()` + `is_relative_to`，不够健壮；② Markdown 内联解析器对普通文本未转义即插入 `innerHTML`，存在 Stored XSS 路径。

由于系统为本地开发工具（仅在开发者机器上运行，访问者即仓库维护者），上述 MEDIUM 问题的实际攻击面较窄，但建议在下一个迭代中修复路径校验逻辑和 XSS 问题，以符合安全最佳实践。

**判定：PASS**（0 CRITICAL，0 HIGH）
