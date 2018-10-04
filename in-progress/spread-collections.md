# Spread Collections

Allow the same `...` spread syntax from [Parameter Freedom][] to be used in list
and map literals to insert multiple elements.

[parameter freedom]: https://github.com/munificent/ui-as-code/blob/master/in-progress/parameter-freedom.md

## Motivation

The "Parameter Freedom" proposal adds rest parameters to remove redundant
collection literals when calling APIs that expect a series of "children"
arguments. If you have an API that expects rest arguments but your values are
already bottled up in a list, you need a way to "unpack" that to use that API.
So the proposal adds a "spread argument" syntax, `...`.

If you have that, it's natural to support the same syntax in collection literals
in order to insert a series of list elements or map entries in the middle of a
list or map.

Code like this is pretty common:

```dart
var args = testArgs.toList()
  ..add('--packages=${PackageMap.globalPackagesPath}')
  ..add('-rexpanded')
  ..addAll(filePaths);
```

The cascade operator does help somewhat, but it's still pretty cumbersome. It
feels imperative when it should be declarative. The user wants to say *what* the
list is, but they are forced to write how it should be *built*, one step at a
time.

With this proposal, it becomes:

```dart
var args = [
  ...testArgs,
  '--packages=${PackageMap.globalPackagesPath}',
  '-rexpanded',
  ...filePaths
];
```

It's not as common, but examples also occur in Flutter UI code, like:

```dart
Widget build(BuildContext context) {
  return CupertinoPageScaffold(
    child: ListView(
      children: [
        Tab2Header(),
      ]..addAll(buildTab2Conversation()),
    ),
  );
}
```

That becomes:

```dart
Widget build(BuildContext context) {
  return CupertinoPageScaffold(
    child: ListView(
      children: [
        Tab2Header(),
        ...buildTab2Conversation(),
      ],
    ),
  );
}
```

Note now how the `]` hangs cleanly at the end instead of being buried by the
trailing `..addAll()`.

The problem is less common when working with maps, but you do sometimes see code
like:

```dart
var params = {
  "userId": 123,
  "timeout": 300,
}..addAll(uri.queryParameters);
```

With this proposal, it becomes:

```dart
var params = {
  "userId": 123,
  "timeout": 300,
  ...uri.queryParameters
};
```

## Syntax

We extend the list grammar to allow *spread elements* in addition to regular
elements:

```
listLiteral:
  const? typeArguments? '[' listElementList? ']'
  ;

listElementList:
  listElement ( ',' listElement )* ','?
  ;

listElement:
  expression |
  '...' expression
  ;
```

Instead of `expressionList`, this uses a new `listElementList` rule since
`expressionList` is used elsewhere in teh grammar where spreads aren't allowed.
Each element in a list is either a normal expression or a spread element.

The changes for map literals are similar:

```
mapLiteral:
  const? typeArguments? '{' mapLiteralEntryList? '}' ;

mapLiteralEntryList:
  mapLiteralEntry ( ',' mapLiteralEntry )* ','?
  ;

mapLiteralEntry:
  expression ':' expression |
  '...' expression
  ;
```

Note that a *spread entry* for a map is an expression, not a key/value pair.

## Static Semantics

Since the spread is unpacked and its individual elements added to the containing
collection, we don't require the spread expression *itself* to be assignable to
the collection's type. For example, this is allowed:

```dart
var numbers = <num>[1, 2, 3];
var ints = <int>[...numbers];
```

This works because the individual elements in `numbers` do happen to have the
right type even though the list that contains them does not. However, the spread
object does need to be "spreadable"&mdash;it must be some kind of Iterable for a
list literal or a Map for a map literal.

It is a static error if:

*   A spread element in a list literal has a static type that is not assignable
    to `Iterable<Object>`.

*   If a list spread element's static type implements `Iterable<T>` for some `T`
    and `T` is not assignable to the element type of the list.

*   A spread element in a map literal has a static type that is not assignable
    to `Map<Object, Object>`.

*   If a map spread element's static type implements `Map<K, V>` for some `K`
    and `V` and `K` is not assignable to the key type of the map or `V` is not
    assignable to the value type of the map.

### Const spreads

Spread elements are not allowed in const lists or maps. Because the spread must
be imperatively unpacked, this could require arbitrary code to be executed at
compile time:

```dart
class InfiniteSequence implements Iterable<int> {
  const InfiniteSequence();

  Iterator<int> get iterator {
    return () sync* {
      var i = 0;
      while (true) yield i ++;
    }();
  }
}

const forever = [InfiniteSequence()];
```

### Type inference

Inference propagates upwards and downwards like you would expect:

*   If a list literal has a downwards inference type of `List<T>` for some `T`,
    then the downwards inference context type of a spread element in that list
    is `Iterable<T>`.

*   If a spread element in a list literal has type `Iterable<T>` for some `T`,
    then the upwards inference element type is `T`.

*   If a map literal has a downwards inference type of `Map<K, V>` for some `K`
    and `V`, then the downwards inference context type of a spread element in
    that map is `Map<K, V>`.

*   If a spread element in a map literal has type `Map<K, V>` for some `K` and
    `V`, then the upwards inference key type is `K` and the value type is `V`.

## Dynamic Semantics

The new dynamic semantics are a superset of the original behavior:

### Lists

A list literal `<E>[elem_1 ... elem_n]` is evaluated as follows:

1.  Create a fresh instance of `list` of a class that implements `List<E>`.

    An implementation is, of course, free to optimize pre-allocate a list of the
    correct capacity when its size is statically known. Note that when spread
    arguments come into play, it's no longer always possible to statically tell
    the final size of the resulting flattened list.

1.  For each `element` in the list literal:

    1.  Evaluate the element's expression to a value `value`.

    1.  If `element` is a spread element:

        1.  Evaluate `value.iterator` to a value `iterator`.

        1.  Loop:

            1.  If `iterator.moveNext()` returns `false`, exit the loop.

            1.  Evaluate `iterator.current` and append the result to `list`.

    1.  Else:

        1.  Append `value` to `list`.

1.  The result of the literal expression is `list`.

### Maps

A map literal of the form `<K, V>{entry_1 ... entry_n}` is evaluated as follows:

1.  Allocate a fresh instance `map` of a class that implements `LinkedHashMap<K,
    V>`.

1.  For each `entry` in the map literal:

    1.  If `entry` is a spread element:

        1.  Evaluate `entry.entries.iterator` to a value `iterator`.

        1.  Loop:

            1.  If `iterator.moveNext()` returns `false`, exit the loop.

            1.  Evaluate `iterator.current` to a value `newEntry`.

            1.  Call `map[newEntry.key] = value`.

    1.  Else, `entry` has form `e1: e2`:

        1.  Evaluate `e1` to a value `key`.

        1.  Evaluate `e2` to a value `value`.

        1.  Call `map[key] = value`.

1.  The result of the map literal expression is `map`.

## Migration

This is a non-breaking change that purely makes existing semantics more easily
expressible.

It would be excellent to build a quick fix for IDEs that recognizes patterns
like `[stuff]..addAll(more)` and transforms it to use `...` instead.

## Next Steps

This proposal is technically not dependent on "Parameter Freedom", but it would
be strange to support spread arguments in collection literals but nowhere else.
We probably want both. However, because they don't depend on each other, it's
possible to implement them in parallel.

Before committing to do that, we should talk to the implementation teams about
feasibility. I would be surprised if there were major concerns.

## Questions and Alternatives

### Why the `...` syntax?

Both Java and JavaScript use `...` for rest parameters and [spread
arguments][js], so I think it is the most familiar syntax to users likely to
come to Dart.

[js]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Spread_syntax

In Dart, `sync*`, `async*`, and `yield*`, all imply that `*` means "many". We
could use that instead of `...`, which is what Scala and Ruby do. However, I
think that is harder to read in contexts where an expression is expected:

```dart
var args = [
  *testArgs,
  '--packages=${PackageMap.globalPackagesPath}',
  '-rexpanded',
  *filePaths
];
```

`*` is already a common infix operator, so having it mean something entirely
different in prefix position feels like the wrong approach. If this is
contentious, it's an easy question to get data on with a usability study.

### Null-aware spread

In this proposal, you will get a runtime error if a spread argument expression
evaluates to null. The null is passed to `addAll()`, which tries to call
`.iterator` on it, and bad things happen.

I believe this is the right *default* behavior. However, in looking through a
corpus for places where a spread argument would be useful, I found a number of
examples like:

```dart
var command = [
  engineDartPath,
  '--target=flutter',
];
if (extraFrontEndOptions != null)
  command.addAll(extraFrontEndOptions);
command.add(mainPath);
```

The null check means, this example can't take advantage of spread. We could add
a `...?` "null-aware spread" operator. In cases where the spread expression
evaluates to null, that expands to an empty collection instead of throwing a
runtime expression.

That would turn the above example to:

```dart
var command = [
  engineDartPath,
  '--target=flutter',
  ...?extraFrontEndOptions,
  mainPath
];
```

More complex conditional expressions than simple null checks come up often too,
but those are out of scope for this proposal.
