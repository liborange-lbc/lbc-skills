# 可读性检查（参考 阿里巴巴 Java 代码风格）

> 审查时按 A1–A7 逐节扫描变更文件。命中违规标 P2（一般风格）或 P1（严重影响可读性/可维护性）。

---

## A1 源文件格式

| ID | 规则 |
|---|------|
| A1.1 | 文件名 = 顶层类名 + `.java`，大小写敏感 |
| A1.2 | 编码 UTF-8 |
| A1.3 | 空白仅允许 ASCII 空格 (0x20) 和换行符，禁止 Tab |

---

## A2 源文件结构

| ID | 规则 |
|---|------|
| A2.1 | 文件顺序：许可证（可选）→ package → import → 一个顶层类，各部分间空行 |
| A2.2 | **禁止 `import *`**（通配符引入） |
| A2.3 | import 分两组：**静态 import** / **非静态 import**，组间空一行 |
| A2.4 | 每组内按完整引入名 ASCII 字典序正序排列 |
| A2.5 | 重载方法连续放置，中间无其他成员 |

---

## A3 代码样式

| ID | 规则 |
|---|------|
| A3.1 | **K&R 大括号**：左括号前不换行、后换行；右括号前换行；`} else {` 同行 |
| A3.2 | 多语句块中的空 catch/finally 不可简写为 `{}` |
| A3.3 | **缩进 4 空格**，禁止 Tab；续行至少 8 空格 |
| A3.4 | **行宽 ≤ 120 字符**（package/import/Javadoc URL 例外） |
| A3.5 | 换行：非赋值运算符**前**换行，赋值运算符**后**换行，方法名与 `(` 不换行，逗号留在前行 |
| A3.6 | 类成员之间必须空行 |
| A3.7 | 关键字与 `(` 之间加空格（`if (`），`}` 与 `else`/`catch` 之间加空格 |
| A3.8 | 二元/三元运算符两侧加空格；`::` 和 `.` 不加空格 |

---

## A4 命名规范

| ID | 标识符 | 风格 | 检测要点 |
|----|--------|------|----------|
| A4.1 | 包名 | 全小写+数字 | 禁止大写或下划线 |
| A4.2 | 类名 | UpperCamelCase | 缩写词也按驼峰拆分：`XmlHttpRequest` 非 `XMLHTTPRequest` |
| A4.3 | 方法名 | lowerCamelCase | — |
| A4.4 | 常量 | UPPER_SNAKE_CASE | 仅 `static final` 且不可变才算常量；`static final Set<> mutable` 不算 |
| A4.5 | 非常量字段/参数/局部变量 | lowerCamelCase | 禁止前缀后缀（`mName`、`name_`、`kName`） |
| A4.6 | 泛型 | 单大写字母或类名+T | `E`, `T`, `RequestT` |
| A4.7 | 测试类 | 被测类名+Test | `DeviceControllerTest` |

---

## A5 编码实践

| ID | 规则 |
|---|------|
| A5.1 | 重写方法**必须**加 `@Override`（父方法 `@Deprecated` 时可省略） |
| A5.2 | catch 块不可为空——至少写注释说明忽略原因；测试中 `expected` 变量名可免 |
| A5.3 | 静态方法用类名调用（`Foo.bar()`），禁止通过实例调用 |
| A5.4 | **禁止**重写 `Object.finalize()` |

---

## A6 特定元素样式

| ID | 规则 |
|---|------|
| A6.1 | 数组方括号属于类型：`String[] args`，禁止 C 风格 `String args[]` |
| A6.2 | switch：fall-through 必须注释 `// fall through`；必须有 `default`（枚举全覆盖例外） |
| A6.3 | 修饰符顺序：`public protected private abstract default static final transient volatile synchronized native strictfp` |
| A6.4 | 注解：类/方法注解每行一个；字段注解可同行多个；单个无参注解可与方法同行 |
| A6.5 | long 字面量用大写 `L`（`3000000000L`），禁止小写 `l` |

---

## A7 Javadoc 规范

| ID | 规则 |
|---|------|
| A7.1 | public 类、public/protected 成员**必须**有 Javadoc |
| A7.2 | 块标记顺序：`@param` → `@return` → `@throws` → `@deprecated` |
| A7.3 | 名称已自解释的简单 getter（如 `getFoo()`）或 `@Override` 方法可省略 |
| A7.4 | 多段落用空行 + `<p>` 分隔 |
