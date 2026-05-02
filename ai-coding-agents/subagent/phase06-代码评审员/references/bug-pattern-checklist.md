# Java Bug Pattern Checklist

> 共120条规则 | Blocker(81) · Major(27) · Info(10) · Reserve(2)
>
> **Step 4（可靠性）**：本清单纳入 `dtazziboot-java-code-review` 的 **Step 4 — 可靠性检查**，与 `reliability-checklist.md`（G）、`security-checklist.md`（S）并列核销。落报告时 **Blocker→P0、Major→P1、Info→P2**。**执行阶段须优先**运行 `references/script/scan-all-rules.sh` 合并可程序化命中，其余由 **LLM/人工** 按 **B*/M*/I*** ID 逐条核对并写 `path:line`。

## Blocker

| ID | 规则名 | 要求 | 反例 | 正例 |
|----|--------|------|------|------|
| B001 | AlwaysThrows | 禁止用字面量调用必定抛异常的parse/of方法（`LocalDateTime.parse`、`UUID.fromString`、`ImmutableMap.of`等） | `LocalDateTime.parse("2022-08-02T22:45:00+08:00")` | `LocalDateTime.parse("2022-08-02T22:45:00")` |
| B002 | ArrayEquals | 比较数组内容应使用`Arrays.equals()`，`array.equals()`比较的是引用 | `array1.equals(array2)` | `Arrays.equals(array1, array2)` |
| B003 | ArrayFillIncompatibleType | `Arrays.fill`禁止填充与数组元素类型不兼容的对象，运行时抛`ArrayStoreException` | `String[] a = new String[42]; Arrays.fill(a, 42);` | `Arrays.fill(a, "life");` |
| B004 | ArrayToString | 数组`toString()`输出引用地址，应使用`Arrays.toString()` | `intArray.toString()` | `Arrays.toString(intArray)` |
| B005 | ArraysAsListPrimitiveArray | `Arrays.asList`不能自动装箱基本类型数组，返回`List<int[]>`而非`List<Integer>` | `Arrays.asList(intArray)` | `Arrays.stream(intArray).boxed().collect(Collectors.toList())` |
| B006 | AssertEqualsArgumentOrderChecker | JUnit `assertEquals(expected, actual)` 参数顺序不可颠倒，否则失败信息有误导性 | `assertEquals(actual, expected)` | `assertEquals(expected, actual)` |
| B007 | AssertionFailureIgnored | 禁止捕获`Throwable`/`Error`导致JUnit断言失败被吞掉 | `catch (Throwable e) { }` | `catch (NumberFormatException e) { }` |
| B008 | AvoidUsingExecutors | 禁止用`Executors`创建线程池，应通过`ThreadPoolExecutor`显式设定参数 | `Executors.newCachedThreadPool()` | `new ThreadPoolExecutor(core, max, 1, HOURS, queue)` |
| B009 | BadShiftAmount | 对int移位超过31位无意义，需检查是否遗漏`L`后缀 | `long l = 114514 << 32;` | `long l = 114514L << 32;` |
| B010 | BigDecimalLiteralDouble | 禁止`new BigDecimal(double)`，会产生精度损失 | `new BigDecimal(0.2)` | `BigDecimal.valueOf(0.2)` 或 `new BigDecimal("0.2")` |
| B011 | BoxedPrimitiveEquality | 包装类型禁止用`==`比较，缓存范围外结果不可靠 | `Long x == Long y` | `Objects.equals(x, y)` |
| B012 | CalendarAddFixedDays | 禁止对Calendar直接加365天，闰年为366天 | `start.add(Calendar.DATE, 365)` | `start.add(Calendar.YEAR, 1)` |
| B013 | CalendarSetHour | `Calendar.HOUR`是12小时制，业务中通常应使用`HOUR_OF_DAY`（24小时制） | `now.set(Calendar.HOUR, 12)` | `now.set(Calendar.HOUR_OF_DAY, 12)` |
| B014 | CollectionIncompatibleType | 集合查询传入与泛型不兼容的类型必定返回null/false | `Map<Long,String> m; m.get(1)` | `m.get(1L)` |
| B015 | CollectionToArraySafeParameter | `Collection.toArray(T[])`传入类型不匹配的数组会抛`ArrayStoreException` | `Collection<Integer> c; c.toArray(new String[0])` | `c.toArray(new Integer[0])` |
| B016 | ComparableType | `Comparable<T>`的泛型T应与实现类一致，否则违反`compareTo`对称性 | `class A implements Comparable<B>` | `class A implements Comparable<A>` |
| B017 | ComparingThisWithNull | `this`不可能为null，`this == null`恒false | `if (this == null)` | 移除此判断 |
| B018 | ConditionalExpressionNumericPromotion | 三目运算符两个数值分支类型不同会触发类型提升，结果类型不符预期 | `flag ? Double.valueOf(0) : Integer.valueOf(0)` | `flag ? (Object)Double.valueOf(0) : (Object)Integer.valueOf(0)` |
| B019 | ConfusableMoneyApi | Money类`addTo`修改原对象返回自身，`add`返回新对象，禁止混淆 | `original.add(one); return original;` | `Money r = original.add(one); return r;` |
| B020 | ConstantOverflow | 编译期常量乘法可能溢出int范围，首个操作数应加`L`后缀 | `long N = 24 * 60 * 60 * 1000 * 1000 * 1000;` | `long N = 24L * 60 * 60 * 1000 * 1000 * 1000;` |
| B021 | DangerousJedisUsage | Jedis设置`blockWhenExhausted=true,maxWait=-1`会无限等待；连接需用后在finally/try-with-resource中close | — | 设置maxWait超时；用`try(Jedis j = pool.getResource()){...}` |
| B022 | DateFormatThreadSafety | `SimpleDateFormat`非线程安全，应使用`DateTimeFormatter` | `static SimpleDateFormat fmt = ...` | `static DateTimeFormatter fmt = ...` |
| B023 | DeadException | 创建了异常实例但未抛出，通常遗漏`throw` | `new SomeException();` | `throw new SomeException();` |
| B024 | DeadThread | 创建Thread实例但未调用`start()` | `new Thread();` | `new Thread(); t.start();` |
| B025 | DoubleBraceInitialization | 禁止双括号初始化集合，会创建匿名内部类导致内存泄漏 | `new HashMap<>() {{ put(1,"1"); }}` | `Map.of(1, "1")` 或普通put |
| B026 | EqualsNull | `x.equals(null)`恒返回false或抛NPE，判null应用`==` | `obj.equals(null)` | `obj == null` |
| B027 | EqualsWrongThing | `equals`方法中比较了不相关的属性 | `a == that.a && b == that.a` | `a == that.a && b == that.b` |
| B028 | ErroneousDateUtil | 禁止使用`commons.httpclient.DateUtil.formatDate()`，默认GMT时区差8小时 | `DateUtil.formatDate(date)` | `date.toInstant().atZone(ZoneId.of("GMT+8")).format(...)` |
| B029 | ErroneousPojoSetter | setter方法赋值给了错误的字段 | `setName(name) { this.address = name; }` | `setName(name) { this.name = name; }` |
| B030 | FloatValueEquality | 禁止用`==`比较浮点数，应通过BigDecimal或指定误差 | `double x == double y` | `Math.abs(x - y) < eps` |
| B031 | FormatString | `String.format`占位符数量必须与参数数量一致 | `String.format("%s %s %s %s", a,b,c,d,e)` | `String.format("%s %s %s %s %s", a,b,c,d,e)` |
| B032 | GetClassOnAnnotation | 注解实例`getClass()`返回代理类，应使用`annotationType()` | `annotation.getClass()` | `annotation.annotationType()` |
| B033 | GetStringBaseArrayByUnsafe | JDK11中String底层由`char[]`改为`byte[]`，Unsafe获取需对应修改 | `(char[]) unsafe.getObject(str, ...)` | `(byte[]) unsafe.getObject(str, ...)` |
| B034 | HashtableContains | `Hashtable.contains()`检查的是值集合，常被误用为`containsKey` | `hashtable.contains("key")` | `hashtable.containsKey("key")` |
| B035 | IdentityBinaryExpression | 同一对象作为二元运算两侧参数无意义（`a&&a`=a, `a==a`=true, `a-a`=0） | `x.check() && x.check()` | `boolean r = x.check(); r && x.check()` |
| B036 | IdentityHashMapBoxing | 禁止用包装类型作`IdentityHashMap`的key，缓存机制导致引用比较不可靠 | `new IdentityHashMap<Integer,String>()` | `new HashMap<Integer,String>()` |
| B037 | InexactVarargsConditional | 可变参数中条件表达式混用数组和非数组分支会导致数组被额外包装 | `varargs(flag ? new Object[]{1,2} : 3)` | `varargs(flag ? new Object[]{1,2} : new Object[]{3})` |
| B038 | InfiniteRecursion | 方法无条件递归调用自身，必导致栈溢出 | `void f() { f(); }` | `void f(boolean c) { if(c) f(newC); }` |
| B039 | IndexOfChar | `String.indexOf(int ch, int fromIndex)`第一个参数是字符，第二个是起始位置，不可颠倒 | `s.indexOf(fromIndex, ch)` | `s.indexOf(ch, fromIndex)` |
| B040 | IsInstanceIncompatibleType | `Class.isInstance()`对不可能匹配的类型调用始终返回false | `Plant.class.isInstance(animal)` (animal extends Animal) | `Cat.class.isInstance(animal)` |
| B041 | JdbcConnectionNotRetrieveImmediately | JDBC连接用完后应在finally中立即回收，禁止在catch块中关闭 | 在catch块中`conn.close()` | 在finally块中`conn.close()` |
| B042 | JUnit3TestNotRun | JUnit3测试方法须public非static且以test开头，否则不执行 | `private void testX()` | `public void testSomething()` |
| B043 | JUnit4TestsNotRunWithinEnclosed | 内部类中的`@Test`方法不会被JUnit执行 | 内部类方法加`@Test` | 移除注解或在外部方法中调用 |
| B044 | JUnitAmbiguousTestClass | 禁止同时使用JUnit3（继承TestCase）和JUnit4（@RunWith） | `@RunWith(JUnit4.class) class T extends TestCase` | `@RunWith(JUnit4.class) class T` |
| B045 | LockOnBoxedPrimitive | 禁止对包装类型对象加锁，缓存机制可能导致意外共享锁 | `synchronized(integerLock)` | `synchronized(new Object())` |
| B046 | LoopConditionChecker | 循环条件在循环体内从未更新，必导致死循环或不执行 | `while(cond) { /* cond未更新 */ }` | `while(cond) { ... cond = update(); }` |
| B047 | LossyPrimitiveCompare | 数值compare方法的类型转换可能导致精度损失 | `Float.compare(Integer.MAX_VALUE, Integer.MAX_VALUE-1)` 返回0 | `Integer.compare(Integer.MAX_VALUE, Integer.MAX_VALUE-1)` |
| B048 | MathRoundIntLong | `Math.round()`接受浮点数，传入整型会被截断 | `Math.round(1L + Integer.MAX_VALUE)` | `Math.round(3.2)` |
| B049 | MisusedDayOfYear | 日期格式`DD`是年内天数，与`MM`一起使用是误用，应用小写`dd` | `"yyyy-MM-DD"` | `"yyyy-MM-dd"` |
| B050 | MisusedHourFormat | 12小时制`hh`须配合`a`（AM/PM），24小时制`HH`不应配`a` | `"hh:mm:ss"` 或 `"HH:mm:ss/a"` | `"hh:mm:ss/a"` 或 `"HH:mm:ss"` |
| B051 | MisusedSystemPropertyGetter | `Boolean.getBoolean()`读系统属性而非解析字符串 | `Boolean.getBoolean("true")` | `Boolean.valueOf("true")` |
| B052 | MisusedWeekYear | `YYYY`是ISO周年，与`MM-dd`搭配是误用，应用`yyyy` | `"YYYY-MM-dd"` | `"yyyy-MM-dd"` |
| B053 | MissingFail | 期望抛异常的try块末尾须添加`Assert.fail()` | `try { method(); } catch(BizEx e) {}` | `try { method(); Assert.fail(); } catch(BizEx e) {}` |
| B054 | MissingTestCall | `EqualsTester`等需调用触发方法才执行检测 | `new EqualsTester().addEqualityGroup(...)` | `new EqualsTester().addEqualityGroup(...).testEquals()` |
| B055 | MockitoUsage | `when()`须跟`thenReturn()`等；`verify()`内不可嵌套调用 | `when(mock.get());` / `verify(mock.execute())` | `when(mock.get()).thenReturn(x);` / `verify(mock).execute()` |
| B056 | ModificationOnArraysAsList | `Arrays.asList()`返回固定大小列表，add/remove抛`UnsupportedOperationException` | `Arrays.asList(arr).add("x")` | `new ArrayList<>(Arrays.asList(arr)).add("x")` |
| B057 | ModifyCollectionInEnhancedForLoop | 禁止在增强for循环中修改集合，抛`ConcurrentModificationException` | `for(String s : list) { list.remove(s); }` | `list.removeIf(s -> s.startsWith("A"))` 或用Iterator |
| B058 | ModifyingCollectionWithItself | 集合方法传入自身作为参数通常是误用 | `collA.retainAll(collA)` | `collA.retainAll(collB)` |
| B059 | NCopiesOfChar | `Collections.nCopies(int n, T o)`第一参数是次数，char隐式转int导致颠倒 | `Collections.nCopies('a', 10)` → 97个10 | `Collections.nCopies(10, 'a')` → 10个'a' |
| B060 | NullTernary | 条件表达式分支含null时自动拆箱抛NPE | `int x = flag ? someInt : null;` | `Integer x = flag ? someInt : null;` |
| B061 | ObsoletedBase64Encoder | 禁止`sun.misc.BASE64Encoder`（JDK11已移除），用`java.util.Base64` | `new sun.misc.BASE64Encoder().encode(b)` | `Base64.getEncoder().encodeToString(b)` |
| B062 | ObsoletedClassLoaderCast | JDK11中`getSystemClassLoader()`不再返回`URLClassLoader`子类 | `(URLClassLoader) ClassLoader.getSystemClassLoader()` | `ClassLoader cl = ClassLoader.getSystemClassLoader()` |
| B063 | ObsoletedJavaxXmlClass | `javax.xml.bind/ws/soap`等包JDK11已移除，需引入对应Maven依赖 | 直接使用`javax.xml.bind.*` | 添加`jaxb-api`等Maven依赖 |
| B064 | OptionalEquality | `Optional`禁止用`==`比较 | `optX == optY` | `optX.equals(optY)` |
| B065 | PojoSelfAssignment | Pojo自赋值无意义，通常遗漏目标对象 | `x.setAttr(x.getAttr())` | `x.setAttr(y.getAttr())` |
| B066 | RandomCast | `Math.random()`返回[0,1)，强转int恒为0 | `(int) Math.random()` | `new Random().nextInt()` |
| B067 | RandomModInteger | `Random.nextInt()`可能返回负数，取余分布不均 | `random.nextInt() % 100` | `random.nextInt(100)` |
| B068 | SelfAssignment | 变量自赋值无意义，通常遗漏`this.` | `name = name;` | `this.name = name;` |
| B069 | SelfComparison | `compareTo`与自身比较恒返回0 | `realPart.compareTo(realPart)` | `realPart.compareTo(other.realPart)` |
| B070 | SelfEquals | `equals`与自身比较恒返回true | `id.equals(id)` | `id.equals(that.id)` |
| B071 | SizeGreaterThanOrEqualsZero | `collection.size() >= 0`恒为true | `collection.size() >= 0` | `!collection.isEmpty()` |
| B072 | StreamToString | `Stream.toString()`输出引用地址无意义 | `stream.toString()` | `Arrays.toString(stream.toArray())` |
| B073 | StringBuilderInitWithChar | StringBuilder无char构造器，传char转int设初始容量 | `new StringBuilder('a')` → 容量97 | `new StringBuilder("a")` → 内容"a" |
| B074 | SubstringOfZero | `substring(0)`返回原字符串，无意义 | `str.substring(0)` | `str.substring(1)` |
| B075 | SuspiciousForLoop | for循环退出条件与增量方向矛盾，导致死循环或不执行 | `for(int i=0; i>=size; i++)` | `for(int i=0; i<size; i++)` |
| B076 | TransactionalNonPublicMethod | `@Transactional`注解在非public方法上无效（Spring AOP限制） | `@Transactional private void write()` | `@Transactional public void write()` |
| B077 | TryFailThrowable | 单测中捕获`Throwable`/`Error`会吞掉`AssertionError` | `catch (Throwable t) { }` | `catch (Throwable t) { if(t instanceof AssertionError) throw t; }` |
| B078 | TruthSelfEquals | `assertThat(x).isEqualTo(x)`传入同一对象恒为true | `assertThat(obj).isEqualTo(obj)` | `assertThat(obj1).isEqualTo(obj2)` |
| B079 | UnnecessaryAssignment | `@Mock`对象不应显式赋值，值由Mockito管理 | `@Mock SomeBean b = new SomeBean()` | `@Mock SomeBean b;` |
| B080 | UnitCaseNoAssertionsCheck | 单测须包含断言语句（assert/verify/check/fail/expect） | `System.out.println("result")` | `Assert.assertEquals(expected, actual)` |
| B081 | UnusedCollectionModifiedInPlace | 新建集合上调用sort/shuffle后未使用该集合 | `Collections.sort(new ArrayList<>(l)); return l;` | `List s = new ArrayList<>(l); Collections.sort(s); return s;` |

## Major

| ID | 规则名 | 要求 | 反例 | 正例 |
|----|--------|------|------|------|
| M001 | AlreadyChecked | 连续对同一条件变量进行相同判断，可能是逻辑错误 | `if(condA){} else if(condA){}` | `if(condA){} else if(condB){}` |
| M002 | BadInstanceof | 子类`instanceof`父类恒为true（非null时），等同null检查 | `cat instanceof Animal` | `cat != null` |
| M003 | BoxedPrimitiveConstructor | 包装类构造器自JDK9已`@Deprecated`，用`valueOf()` | `new Long("100")` | `Long.valueOf("100")` |
| M004 | CatchAndPrintStackTrace | 禁止捕获异常后直接`printStackTrace()`，应记日志或继续抛出 | `e.printStackTrace()` | `logger.error("{}", e)` 或 `throw new CustomEx(e)` |
| M005 | ClassCanBeStatic | 未引用外部类成员的内部类应声明为`static` | `class Outer { class Inner {} }` | `class Outer { static class Inner {} }` |
| M006 | ComplexBooleanConstant | 编译期可确定值的布尔表达式通常是BUG | `if (1 < 4 && r > 8)` | `if (l < 4 && r > 8)` |
| M007 | EmptyCatch | catch块不应为空，需处理异常或注释说明原因 | `catch (Exception e) { }` | `catch (Exception e) { logger.error("{}", e); }` |
| M008 | EqualsHashCode | 重写`equals()`必须同时重写`hashCode()`，否则Hash容器异常 | 只重写`equals` | 同时重写`equals`和`hashCode` |
| M009 | EqualsIncompatibleType | 不可能相等的类型间调用`equals()`恒返回false | `cat.equals(dog)` | `cat.owner.equals(dog.owner)` |
| M010 | ErroneousBitwiseExpression | 位运算结果始终为0（如`1 & 2`），可能是BUG | `int r = 1 & 2;` | `int r = l & 2;` |
| M011 | FallThrough | switch每个case组（除最后一个）应以break/return/throw结束或注释fall through | `case 5: doA(); case 6: doB(); break;` | `case 5: doA(); break; case 6: doB(); break;` |
| M012 | Finally | 禁止在finally块中return或throw，会覆盖try/catch的返回值或异常 | `finally { return x; }` | `finally { cleanup(); }` |
| M013 | FloatCast | 类型转换优先级高于算术运算，需用括号明确范围 | `(long) 0.5 * 1024` → 0L | `(long)(0.5 * 1024)` |
| M014 | GetClassOnEnum | 枚举实例`getClass()`可能返回子类，应用`getDeclaringClass()` | `Color.VIOLET.getClass()` → Color$7 | `Color.VIOLET.getDeclaringClass()` → Color |
| M015 | HidingField | 子类变量名禁止与父类同名，会隐藏父类字段 | `class Son extends Parent { int property; }` | `class Son extends Parent { int sonProp; }` |
| M016 | JavaTimeDefaultTimeZone | 禁止使用依赖系统默认时区的方法，应显式指定 | `LocalDateTime.now()` | `LocalDateTime.now(ZoneId.of("UTC+8"))` |
| M017 | JUnit4TestNotRun | 似乎是测试方法但缺少`@Test`注解，不会执行 | `public void testX() {}` | `@Test public void testX() {}` |
| M018 | LockNotBeforeTry | `lock()`后应紧跟try-finally释放锁，中间不应有其他调用 | `lock(); mayThrow(); try{} finally{unlock();}` | `lock(); try{} finally{unlock();}` |
| M019 | MissingCasesInEnumSwitch | switch枚举类型应覆盖所有值或提供default分支 | switch缺少部分枚举值且无default | 覆盖所有枚举值或加default |
| M020 | MissingOverride | 重写父类/接口方法必须添加`@Override`注解 | `void function() {}` (重写但无注解) | `@Override void function() {}` |
| M021 | NonOverridingEquals | `equals(SpecificType)`不会重写`Object.equals(Object)` | `public boolean equals(Example o)` | `@Override public boolean equals(Object o)` |
| M022 | NullOptional | `Optional.of(null)`抛NPE，`ofNullable(null)`等同`empty()` | `Optional.of(null)` | `Optional.empty()` |
| M023 | ObjectToString | 对未重写`toString()`的类调用打印输出无意义信息 | `System.out.println(person)` | `System.out.println(person.name)` |
| M024 | OptionalNotPresent | 已确认为空的Optional调用`get()`必抛异常 | `if(!opt.isPresent()) { opt.get(); }` | `opt.orElse("default")` |
| M025 | ProtectedMembersInFinalClass | final类中`protected`修饰符无意义，应改包级私有 | `final class C { protected String s; }` | `final class C { String s; }` |
| M026 | StaticMockMember | `@Mock`对象禁止声明为static，不应跨测试共享 | `@Mock static SomeBean b;` | `@Mock SomeBean b;` |
| M027 | ThreadLocalUsage | `ThreadLocal`须声明为`static`，否则浪费资源且可能内存泄漏 | `private final ThreadLocal<Integer> tl` | `private static final ThreadLocal<Integer> tl` |

## Info

| ID | 规则名 | 要求 | 反例 | 正例 |
|----|--------|------|------|------|
| I001 | AssertExceptionDetailInfoPreferred | 建议对异常的错误码或消息断言，而非仅判断类型 | `@Test(expected = BizException.class)` | `catch(BizEx e) { assertThat(e).hasMessage("msg"); }` |
| I002 | DoNotMock | 被`@DoNotMock`注解的类不应使用`@Mock` | `@Mock DoNotMockClass x` | 移除`@Mock` |
| I003 | DoNotMockAutoValue | 被`@AutoValue`注解的类不应使用`@Mock` | `@Mock AutoValueClass x` | 移除`@Mock` |
| I004 | JavaUtilDate | 建议避免`java.util.Date`，用`Instant`或`LocalDateTime` | `new Date()` | `LocalDateTime.now(ZoneId.systemDefault())` |
| I005 | JUnit4ClassUsedInJUnit3 | `@Ignore`/`@Rule`/`Assume`等JUnit4特性在JUnit3中不生效 | JUnit3中使用`@Ignore` | 升级到JUnit4 |
| I006 | JUnit4SetUpNotRun | JUnit4中`setUp()`需添加`@Before`注解才执行 | `public void setUp() {}` | `@Before public void setUp() {}` |
| I007 | JUnit4TearDownNotRun | JUnit4中`tearDown()`需添加`@After`注解才执行 | `public void tearDown() {}` | `@After public void tearDown() {}` |
| I008 | JUnitParameterMethodNotFound | 单测声明了`dataProvider`但未找到对应`@DataProvider`方法 | `@Test(dataProvider="p")` 但无`@DataProvider(name="p")` | 添加对应的`@DataProvider`方法 |
| I009 | UnitCaseCount | 检测方法是否为单测方法（仅供统计，勿在线上开启） | — | — |
| I010 | UnitCaseRunnerCheck | 需要启动Spring/Pandora容器的测试建议放集成测试运行 | `@RunWith(PandoraBootRunner.class)` | `@RunWith(JUnit4.class)` |
