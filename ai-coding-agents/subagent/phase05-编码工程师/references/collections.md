# 集合处理规约

## 1. hashCode和equals

**【强制】** 关于hashCode和equals的处理，遵循如下规则：

1. 只要覆写equals，就必须覆写hashCode
2. 因为Set存储的是不重复的对象，依据hashCode和equals进行判断，所以Set存储的对象必须覆写这两个方法
3. 如果自定义对象作为Map的键，那么必须覆写hashCode和equals

**说明**：String正因为覆写了hashCode和equals方法，所以可以非常愉快地使用String对象作为key来使用。

## 2. 集合操作注意事项

### 2.1 修改操作

**【强制】** 使用Map的方法keySet()/values()/entrySet()返回集合对象时，不可以对其进行添加元素操作，否则会抛出UnsupportedOperationException异常。

**【强制】** Collections类返回的对象，如：emptyList()/singletonList()等都是immutable list，不可对其进行添加或者删除元素的操作。

**【强制】** 使用工具类Arrays.asList()把数组转换成集合时，不能使用其修改集合相关的方法，它的add/remove/clear方法会抛出UnsupportedOperationException异常。

### 2.2 subList注意事项

**【强制】** ArrayList的subList结果不可强转成ArrayList，否则会抛出ClassCastException异常。

**【强制】** 在subList场景中，高度注意对父集合元素的增加或删除，均会导致子列表的遍历、增加、删除产生ConcurrentModificationException异常。

## 3. Stream与Collectors

### 3.1 toMap的合并函数

**【强制】** 在使用java.util.stream.Collectors类的toMap()方法转为Map集合时，一定要使用含有参数类型为BinaryOperator，参数名为mergeFunction的方法，否则当出现相同key值时会抛出IllegalStateException异常。

**正例**：
```java
List<Pair<String, Double>> pairArrayList = new ArrayList<>(3);
pairArrayList.add(new Pair<>("version", 6.19));
pairArrayList.add(new Pair<>("version", 10.24));
pairArrayList.add(new Pair<>("version", 13.14));

Map<String, Double> map = pairArrayList.stream().collect(
    // 生成的map集合中只有一个键值对：{version=13.14}
    Collectors.toMap(Pair::getKey, Pair::getValue, (v1, v2) -> v2)
);
```

**反例**：
```java
// 抛出IllegalStateException异常
Map<Integer, String> map = Arrays.stream(departments)
    .collect(Collectors.toMap(String::hashCode, str -> str));
```

### 3.2 toMap空值处理

**【强制】** 在使用java.util.stream.Collectors类的toMap()方法转为Map集合时，一定要注意当value为null时会抛NPE异常。

## 4. 集合转数组

**【强制】** 使用集合转数组的方法，必须使用集合的toArray(T[] array)，传入的是类型完全一致、长度为0的空数组。

**正例**：
```java
List<String> list = new ArrayList<>(2);
list.add("guan");
list.add("bao");

// 使用长度为0的数组
String[] array = list.toArray(new String[0]);
```

**说明**：
- 等于0，动态创建与size相同的数组，性能最好
- 大于0但小于size，重新创建大小等于size的数组，增加GC负担
- 等于size，在高并发情况下有负面影响
- 大于size，空间浪费，且存在NPE隐患

## 5. 集合遍历

### 5.1 foreach循环

**【强制】** 不要在foreach循环里进行元素的remove/add操作。remove元素请使用Iterator方式，如果并发操作，需要对Iterator对象加锁。

**反例**：
```java
List<String> list = new ArrayList<>();
list.add("targetItem");
list.add("other");

// 抛出ConcurrentModificationException
for (String item : list) {
    if ("targetItem".equals(item)) {
        list.remove(item);
    }
}
```

**正例**：
```java
Iterator<String> iterator = list.iterator();
while (iterator.hasNext()) {
    String item = iterator.next();
    if ("targetItem".equals(item)) {
        iterator.remove();
    }
}
```

### 5.2 Map遍历

**【推荐】** 使用entrySet遍历Map类集合KV，而不是keySet方式进行遍历。

**说明**：keySet其实是遍历了2次，一次是转为Iterator对象，另一次是从hashMap中取出key所对应的value。而entrySet只是遍历了一次就把key和value都放到了entry中。

**正例**：
```java
Map<String, Integer> map = new HashMap<>();
// 推荐
for (Map.Entry<String, Integer> entry : map.entrySet()) {
    String key = entry.getKey();
    Integer value = entry.getValue();
}

// JDK8推荐
map.forEach((key, value) -> {
    // ...
});
```

## 6. 集合初始化

**【推荐】** 集合初始化时，指定集合初始值大小。

**说明**：HashMap使用构造方法`new HashMap(int initialCapacity)`进行初始化。关于扩容时机与容量分配的关系，如果暂时无法确定集合大小，那么指定默认值（16）即可。

**反例**：
```java
// HashMap需要放置1024个元素，由于没有设置容量初始大小
// resize()方法总共会调用8次，反复重建哈希表和数据迁移
HashMap<String, Object> map = new HashMap<>();
for (int i = 0; i < 1024; i++) {
    map.put("key" + i, i);
}
```

## 7. 泛型使用

### 7.1 菱形语法

**【推荐】** 泛型集合使用时，在JDK7版本及以上，使用 diamond 语法或全省略。

**正例**：
```java
// diamond 方式
HashMap<String, String> userCache = new HashMap<>(16);

// 全省略方式
ArrayList<User> users = new ArrayList(10);
```

### 7.2 PECS原则

**【强制】** 泛型通配符`<? extends T>`来接收返回的数据，此写法的泛型集合不能使用add方法，而`<? super T>`不能使用get方法。

**说明**：PECS (Producer Extends Consumer Super)原则：
- 频繁往外读取内容的，适合用`<? extends T>`
- 经常往里插入的，适合用`<? super T>`

## 8. Map可空值

**【推荐】** 高度注意Map类集合K/V能不能存储null值的情况：

| 集合类 | Key | Value | 说明 |
|--------|-----|-------|------|
| Hashtable | 不允许 | 不允许 | 线程安全 |
| ConcurrentHashMap | 不允许 | 不允许 | 线程安全 |
| TreeMap | 不允许 | 允许 | 线程不安全 |
| HashMap | 允许 | 允许 | 线程不安全 |

## 9. Comparator规范

**【强制】** 在JDK7版本以上，Comparator要满足如下三个条件：

1. x，y的比较结果和y，x的比较结果相反
2. x>y，y>z，则x>z
3. x=y，则x，z比较结果和y，z比较结果相同

**反例**：
```java
// 没有处理相等的情况
new Comparator<Student>() {
    @Override
    public int compare(Student o1, Student o2) {
        return o1.getId() > o2.getId() ? 1 : -1;
    }
}
```

## 检查清单

集合处理检查时关注：

- [ ] 覆写equals同时覆写hashCode
- [ ] 不对keySet()/values()/entrySet()返回的集合做add操作
- [ ] toMap使用mergeFunction处理key冲突
- [ ] toMap注意value为null的情况
- [ ] 集合转数组使用toArray(new String[0])
- [ ] foreach循环里不进行remove/add操作
- [ ] Map遍历使用entrySet或forEach
- [ ] 集合初始化指定初始容量
- [ ] 泛型集合使用diamond语法
- [ ] 理解各类Map对null值的限制
