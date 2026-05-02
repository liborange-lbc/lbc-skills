# 并发处理规约

## 1. 线程安全基础

### 1.1 单例对象

**【强制】** 获取单例对象需要保证线程安全，其中的方法也要保证线程安全。

**说明**：资源驱动类、工具类、单例工厂类都需要注意。

### 1.2 线程命名

**【强制】** 创建线程或线程池时请指定有意义的线程名称，方便出错时回溯。

**正例**：
```java
public class UserThreadFactory implements ThreadFactory {
    private final String namePrefix;
    private final AtomicInteger nextId = new AtomicInteger(1);

    UserThreadFactory(String whatFeatureOfGroup) {
        namePrefix = "From UserThreadFactory's " + whatFeatureOfGroup + "-Worker-";
    }

    @Override
    public Thread newThread(Runnable task) {
        String name = namePrefix + nextId.getAndIncrement();
        Thread thread = new Thread(null, task, name, 0, false);
        System.out.println(thread.getName());
        return thread;
    }
}
```

### 1.3 线程池创建

**【强制】** 线程资源必须通过线程池提供，不允许在应用中自行显式创建线程。

**【强制】** 线程池不允许使用Executors去创建，而是通过ThreadPoolExecutor的方式。

**说明**：Executors返回的线程池对象的弊端：
1. FixedThreadPool和SingleThreadPool：允许的请求队列长度为Integer.MAX_VALUE，可能会堆积大量请求，导致OOM
2. CachedThreadPool：允许的创建线程数量为Integer.MAX_VALUE，可能会创建大量线程，导致OOM

**正例**：
```java
ThreadPoolExecutor executor = new ThreadPoolExecutor(
    5,                                      // 核心线程数
    10,                                     // 最大线程数
    60L,                                    // 空闲线程存活时间
    TimeUnit.SECONDS,                       // 时间单位
    new LinkedBlockingQueue<>(100),         // 任务队列
    new UserThreadFactory("order"),         // 线程工厂
    new ThreadPoolExecutor.CallerRunsPolicy() // 拒绝策略
);
```

## 2. 日期线程安全

### 2.1 SimpleDateFormat

**【强制】** SimpleDateFormat是线程不安全的类，一般不要定义为static变量，如果定义为static，必须加锁，或者使用DateUtils工具类。

**正例**：
```java
private static final ThreadLocal<DateFormat> df = new ThreadLocal<DateFormat>() {
    @Override
    protected DateFormat initialValue() {
        return new SimpleDateFormat("yyyy-MM-dd");
    }
};
```

**说明**：JDK8的应用，可以使用`Instant`代替`Date`，`LocalDateTime`代替`Calendar`，`DateTimeFormatter`代替`SimpleDateFormat`。

## 3. ThreadLocal使用

### 3.1 清理规范

**【强制】** 必须回收自定义的ThreadLocal变量，尤其在线程池场景下，线程经常会被复用，如果不清理，可能会影响后续业务逻辑和造成内存泄露等问题。

**正例**：
```java
objectThreadLocal.set(userInfo);
try {
    // 业务逻辑
} finally {
    objectThreadLocal.remove();
}
```

## 4. 锁的使用

### 4.1 锁的性能

**【强制】** 高并发时，同步调用应该去考量锁的性能损耗。能用无锁数据结构，就不要用锁；能锁区块，就不要锁整个方法体；能用对象锁，就不要用类锁。

### 4.2 加锁顺序

**【强制】** 对多个资源、数据库表、对象同时加锁时，需要保持一致的加锁顺序，否则可能会造成死锁。

**说明**：线程一需要对表A、B、C依次全部加锁后才可以进行更新操作，那么线程二的加锁顺序也必须是A、B、C。

### 4.3 加锁位置

**【强制】** 在使用阻塞等待获取锁的方式中，必须在try代码块之外，并且在加锁方法与try代码块之间没有任何可能抛出异常的方法调用。

**正例**：
```java
Lock lock = new ReentrantLock();
lock.lock();
try {
    doSomething();
    doOthers();
} finally {
    lock.unlock();
}
```

**反例**：
```java
// 如果doSomething抛出异常，lock不会被释放
Lock lock = new ReentrantLock();
try {
    doSomething();
    lock.lock();
    doOthers();
} finally {
    lock.unlock();
}
```

### 4.4 tryLock定位

**【强制】** 在使用尝试机制来获取锁的方式中，进入业务代码块之前，必须先判断当前线程是否持有锁。

**正例**：
```java
Lock lock = new ReentrantLock();
boolean isLocked = lock.tryLock();
if (isLocked) {
    try {
        doSomething();
    } finally {
        lock.unlock();
    }
}
```

## 5. 并发更新

### 5.1 更新丢失

**【强制】** 并发修改同一记录时，避免更新丢失，要么在应用层加锁，要么在缓存加锁，要么在数据库层使用乐观锁，使用version作为更新依据。

**说明**：如果每次访问冲突概率小于20%，推荐使用乐观锁，否则使用悲观锁。乐观锁的重试次数不得小于3次。

## 6. Timer和线程池

**【强制】** 多线程并行处理定时任务时，Timer运行多个TimeTask时，只要其中之一没有捕获抛出的异常，其它任务便会自动终止运行，使用ScheduledExecutorService则没有这个问题。

**正例**：
```java
ScheduledExecutorService executorService = Executors.newScheduledThreadPool(5);
executorService.scheduleAtFixedRate(() -> {
    // 定时任务
}, 0, 1, TimeUnit.MINUTES);
```

## 7. 并发编程推荐

### 7.1 金融敏感信息

**【推荐】** 资金相关的金融敏感信息，使用悲观锁策略。

**正例**：悲观锁遵循一锁二判三更新四释放的原则。

### 7.2 异步转同步

**【推荐】** 使用CountDownLatch进行异步转同步操作，每个线程退出前必须调用countDown方法。

**说明**：注意，子线程抛出异常堆栈，不能在主线程try-catch到。

### 7.3 Random和ThreadLocalRandom

**【推荐】** 避免Random实例被多线程使用，虽然共享该实例是线程安全的，但会因竞争同一seed导致的性能下降。

**正例**：JDK7版本及以上，直接使用`ThreadLocalRandom`。

```java
// JDK7+
int randomNum = ThreadLocalRandom.current().nextInt(100);
```

### 7.4 双重检查锁

**【推荐】** 通过双重检查锁实现延迟初始化需要将目标属性声明为volatile型。

**正例**：
```java
public class Singleton {
    private volatile static Singleton instance;

    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}
```

## 8. 并发工具推荐

### 8.1 volatile关键字

**【参考】** volatile解决多线程内存不可见问题。对于一写多读，是可以解决变量同步问题，但是如果多写，同样无法解决线程安全问题。

### 8.2 LongAdder

**【参考】** count++操作如果是JDK8，推荐使用`LongAdder`对象，比`AtomicLong`性能更好（减少乐观锁的重试次数）。

**正例**：
```java
// JDK8推荐
LongAdder count = new LongAdder();
count.increment();
long result = count.sum();
```

### 8.3 HashMap并发风险

**【参考】** HashMap在容量不够进行resize时由于高并发可能出现死链，导致CPU飙升。ConcurrentHashMap是线程安全的替代选择。

## 检查清单

并发处理检查时关注：

- [ ] 使用ThreadPoolExecutor创建线程池，不用Executors
- [ ] SimpleDateFormat不定义为static，或使用ThreadLocal
- [ ] ThreadLocal变量在线程池场景下必须remove
- [ ] 加锁顺序一致，避免死锁
- [ ] lock.lock()在try外面，unlock在finally里
- [ ] 定时任务使用ScheduledExecutorService
- [ ] 并发修改使用乐观锁或悲观锁
- [ ] 金融敏感信息使用悲观锁
- [ ] 双重检查锁配合volatile使用
- [ ] 多线程计数使用LongAdder(JDK8+)
- [ ] HashMap不在高并发写场景使用
