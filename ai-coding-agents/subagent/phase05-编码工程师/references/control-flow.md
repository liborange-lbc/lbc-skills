# 控制语句规约

## 1. switch语句

### 1.1 case终止

**【强制】** 在一个switch块内，每个case要么通过continue/break/return等来终止，要么注释说明程序将继续执行到哪一个case为止；在一个switch块内，都必须包含一个default语句并且放在最后，即使它什么代码也没有。

### 1.2 String类型判断

**【强制】** 当switch括号内的变量类型为String并且此变量为外部参数时，必须先进行null判断。

**反例**：
```java
public static void method(String param) {
    switch (param) {
        case "sth":
            System.out.println("it's sth");
            break;
        case "null":
            System.out.println("it's null");
            break;
        default:
            System.out.println("default");
    }
}

// method(null) 会抛出NullPointerException
```

## 2. 大括号规范

**【强制】** 在if/else/for/while/do语句中必须使用大括号。即使只有一行代码，禁止不采用大括号的编码方式。

**反例**：
```java
if (condition) statements;
```

**正例**：
```java
if (condition) {
    statements;
}
```

## 3. 三目运算符

**【强制】** 三目运算符`condition ? 表达式1 : 表达式2`中，高度注意表达式1和2在涉及算术计算或数据类型转换时，可能抛出因自动拆箱导致的NPE异常。

**说明**：以下两种场景会触发类型对齐的拆箱操作：
1. 表达式1或表达式2的值只要有一个是原始类型
2. 表达式1或表达式2的值的类型不一致，会强制拆箱升级成表示范围更大的那个类型

**反例**：
```java
Integer a = 1;
Integer b = 2;
Integer c = null;
Boolean flag = false;

// a*b的结果是int类型，那么c会强制拆箱成int类型，抛出NPE异常
Integer result = (flag ? a * b : c);
```

## 4. 高并发条件判断

**【强制】** 在高并发场景中，避免使用"等于"判断作为中断或退出的条件。

**说明**：如果并发控制没有处理好，容易产生等值判断被"击穿"的情况，使用大于或小于的区间判断条件来代替。

**反例**：
```java
// 某营销活动发奖，判断剩余奖品数量等于0时，终止发放奖品
// 但因为并发处理错误导致奖品数量瞬间变成了负数，活动无法终止，产生资损
if (prizeCount == 0) {
    stopPrize();
}
```

## 5. 卫语句与嵌套

### 5.1 避免过多else-if

**【推荐】** 表达异常分支时，少用if-else方式，优先使用卫语句（Guard Statements）。

**正例**：
```java
public void findBoyfriend(Man man) {
    if (man.isBadTemper()) {
        System.out.println("月球有多远，你就给我滚多远.");
        return;
    }

    if (man.isShort()) {
        System.out.println("我不需要武大郎一样的男友.");
        return;
    }

    if (man.isPoor()) {
        System.out.println("贫贱夫妻百事哀.");
        return;
    }

    System.out.println("可以先交往一段时间看看.");
}
```

### 5.2 嵌套层数限制

**【推荐】** 如果非得使用if()...else if()...else...方式表达逻辑，请勿超过3层，超过请使用状态设计模式。

**正例**：超过3层的if-else逻辑判断代码可以使用卫语句、策略模式、状态模式等来实现。

## 6. 代码可读性

### 6.1 空行分隔

**【推荐】** 当某个方法的代码总行数超过10行时，return/throw等中断逻辑的右大括号后需要加一个空行。

**说明**：这样做逻辑清晰，在代码阅读时重点关注。

### 6.2 复杂逻辑提取

**【推荐】** 除常用方法（如getXxx/isXxx）等外，不要在条件判断中执行复杂的语句，将复杂逻辑判断的结果赋值给一个有意义的布尔变量，以提高可读性。

**正例**：
```java
// 伪代码
final boolean existed = (file.open(fileName, "w") != null) && (...) || (...);
if (existed) {
    // ...
}
```

### 6.3 禁止赋值语句嵌入

**【推荐】** 不要在其它表达式（尤其是条件表达式）中，插入赋值语句。

**说明**：赋值点类似于人体的穴位，对于代码的理解至关重要，所以赋值语句需要清晰地单独成为一行。

**反例**：
```java
public Lock getLock(boolean fair) {
    // 算术表达式中出现赋值操作，容易忽略count值已经被改变
    threshold = (count = Integer.MAX_VALUE) - 1;
    // 条件表达式中出现赋值操作，容易误认为是sync==fair
    return (sync = fair) ? new FairSync() : new NonfairSync();
}
```

### 6.4 避免取反逻辑

**【推荐】** 避免采用取反逻辑运算符。

**说明**：取反逻辑不利于快速理解，并且取反逻辑写法一般都存在对应的正向逻辑写法。

**正例**：使用`if (x < 628)`来表达x小于628。

**反例**：使用`if (!(x >= 628))`来表达x小于628。

## 7. 循环优化

**【推荐】** 循环体中的语句要考量性能，以下操作尽量移至循环体外处理：
1. 定义对象、变量
2. 获取数据库连接
3. 进行不必要的try-catch操作

## 8. 参数校验

### 8.1 需要参数校验的场景

**【参考】** 下列情形中，需要进行参数校验：
1. 调用频次低的方法
2. 执行时间开销很大的方法
3. 需要极高稳定性和可用性的方法
4. 对外提供的开放接口，不管是HSF/API/HTTP接口
5. 敏感权限入口

### 8.2 不需要参数校验的场景

**【参考】** 下列情形中，不需要进行参数校验：
1. 极有可能被循环调用的方法（但方法说明里必须注明外部参数检查）
2. 底层调用频度比较高的方法
3. 被声明成private只会被自己代码所调用的方法
