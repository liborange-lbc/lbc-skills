# 日期时间规约

## 1. 日期格式化

### 1.1 年份格式

**【强制】** 日期格式化时，传入pattern中表示年份统一使用小写的y。

**说明**：
- `yyyy`：表示当天所在的年
- `YYYY`：表示week in which year（JDK7之后引入），即当天所在的周属于的年份

**正例**：
```java
new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
```

**反例**：
```java
// 一周从周日开始，周六结束，只要本周跨年，返回的YYYY就是下一年
new SimpleDateFormat("YYYY/MM/dd");
// 2017/12/31执行结果为2018/12/31
```

### 1.2 月份和分钟

**【强制】** 在日期格式中分清楚大写的M和小写的m，大写的H和小写的h分别指代的意义。

**说明**：
- M：表示月份
- m：表示分钟
- H：24小时制
- h：12小时制

### 1.3 获取当前时间

**【强制】** 获取当前毫秒数：`System.currentTimeMillis()`，而不是`new Date().getTime()`。

**说明**：如果想获取更加精确的纳秒级时间值，使用`System.nanoTime`的方式。在JDK8中，推荐使用`Instant`类。

### 1.4 禁止使用类型

**【强制】** 不允许在程序任何地方中使用：
1. `java.sql.Date`
2. `java.sql.Time`
3. `java.sql.Timestamp`

## 2. 日期计算

### 2.1 闰年处理

**【强制】** 不要在程序中写死一年为365天，避免在公历闰年时出现日期转换错误或程序逻辑错误。

**正例**：
```java
// 获取今年的天数
int daysOfThisYear = LocalDate.now().lengthOfYear();

// 获取指定某年的天数
LocalDate.of(2011, 1, 1).lengthOfYear();
```

### 2.2 月份枚举

**【推荐】** 使用枚举值来指代月份。如果使用数字，注意Date、Calendar等日期相关类的月份month取值在0-11之间。

**正例**：
```java
Calendar.JANUARY
Calendar.FEBRUARY
Calendar.MARCH
```

## 3. JDK8日期时间API

**【推荐】** JDK8中的应用，推荐使用：
- `Instant`代替Date
- `LocalDateTime`代替Calendar
- `DateTimeFormatter`代替SimpleDateFormat

**说明**：官方给出的解释：simple beautiful strong immutable thread-safe。

**正例**：
```java
// 当前时间
LocalDateTime now = LocalDateTime.now();

// 格式化
DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
String formatted = now.format(formatter);

// 解析
LocalDateTime parsed = LocalDateTime.parse("2024-01-15 10:30:00", formatter);

// 日期计算
LocalDateTime tomorrow = now.plusDays(1);
```
