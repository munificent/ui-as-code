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
feels imperative when it should be declarative. The wants to say *what* the list
is, but they are forced to write how it should be *built*, one step at a time.

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
  return new CupertinoPageScaffold(
    child: new ListView(
      children: <Widget>[
        new Tab2Header(),
      ]..addAll(buildTab2Conversation()),
    ),
  );
}
```

That becomes:

```dart
Widget build(BuildContext context) {
  return new CupertinoPageScaffold(
    child: new ListView(
      children: <Widget>[
        new Tab2Header(),
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

List and map literals are effectively syntactic sugar over the base imperative
List and Map APIs. This proposal makes that explicit by specifying collection literals as a syntax-directed transformation to those APIs.

### Type inference

However, type inference does get some special support. If not already known, the
static type of a list is inferred from its elements:

```dart
var list = [1, 2.3];
```

Here, `list` has type `List<num>`, since `num` is the least upper bound of `1`
and `2.3`.

If the spread element's expression has a type that implements `Iterable<T>` for
some `T`, then the spread element type is `T`. Otherwise, the spread element
type is `dynamic`.

**todo: finish describing how this interacts with upwards and downwards
inference.**

### Syntax-directed transformation

A list literal is syntactic sugar for building a list imperatively using the `List` API. After type inference has completed, a list literal is transformed like so:

1.  Start with `List<T>()`.
2.  For each element in the list:

    1.  If the element is a spread element, append `..addAll(element)`.
    2.  Else, append `..add(element)`.

For example, the list literal:

```dart
[1, ..."234".runes, 5]
```

Transforms to:

```
List<int>()..add(1)..addAll("234".runes)..add(5)
```

This desugaring implies that the list is grown dynamically. An implementation
is, of course, free to optimize this and pre-allocate a list of the correct
capacity when it's size is statically known. Note that when spread arguments
come into play, it's not longer always possible to statically tell the final
size of the resulting flattened list.

Map literals are similar:

1.  Start with `Map<K, V>()`.
2.  For each entry in the map:

    1.  If the entry is a spread entry, append `..addAll(entry)`.
    2.  Else the entry is a `name` `value` pair. Append
        `..addEntries([MapEntry<K, V>(key, value)])`.

        (Yeah, that's pretty verbose. `[]=` would be better, but that doesn't
        support cascades.)

Thus, this:

```dart
var first = {"key": "value"};
var second = {"a": "b", ...first, "c": "d"};
```

Transforms to:

```dart
var first = Map<String, String>()
  ..addEntries([MapEntry<String, String>("key", "value")]);
var second = Map<String, String>()
  ..addEntries([MapEntry<String, String>("a", "b")])
  ..addAll(first)
  ..addEntries([MapEntry<String, String>("c", "d")]);
```

## Dynamic Semantics

There are no dynamic semantics. Once the literals have been transformed to the
base API, they are type-checked and executed in terms of that.

## Migration

This is a non-breaking change that purely makes existing semantics more easily
expressible.

It would be excellent to build a quick fix for IDEs that recognizes patterns
like `[stuff]..addAll(more)` and transforms it to use `...` instead.

## Next Steps

This proposal is technically not dependent on "Parameter Freedom", but it would
be strange to support spread arguments in collection literals but nowhere else.
We probably won't both. However, because they don't depend on each other, it's
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
