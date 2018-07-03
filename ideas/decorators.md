It's fairly common to find a deep series of nested widgets where instead of a
branchy tree, you mostly have a linear series of nested dolls.

```dart
Widget build(BuildContext context) {
  return CupertinoPageScaffold(
    child: SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        children: [
          SizedBox(
            height: 200.0,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              itemExtent: 160.0,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      color: relatedColors[index],
                    ),
                    child: Center(
                      child: CupertinoButton(
                        child: const Icon(
                          CupertinoIcons.plus_circled,
                          color: CupertinoColors.white,
                          size: 36.0,
                        ),
                        onPressed: () { },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
```

(Source: [flutter/examples/flutter_gallery/lib/demo/cupertino/cupertino_navigation_demo.dart][source])

[source]: https://github.com/flutter/flutter/blob/master/examples/flutter_gallery/lib/demo/cupertino/cupertino_navigation_demo.dart#L286-L410

Note all of the `child` parameters here and how deeply they nest.

[Python's decorator syntax][python] lets you place a marker before a
declaration. When the declaration is executed, the decorator is invoked like a
function and passed the declaration as a function. The decorator can do whatever
it wants with the result.

[python]: https://www.python.org/dev/peps/pep-0318/

The `@` syntax is already used in Dart for metadata, which has certain
"compile-time" connotations, so it probably wouldn't make sense. I'm not
attached to any particular syntax. For now, let's try infix `with`:

Let's say that:

```dart
Foo(args) with expr
```

where `Foo` is some callable entity, `args` is an argument list, and `expr` is
some expression, desugars to:

```dart
Foo(args, expr)
```

In other words, the `with` means "grab the following expression and pull it
inside the preceding argument list". In cases where the initial argument list is
empty, the `()` can be omitted.

With that small amount of sugar (and using `=>`) the above example becomes:

```dart
Widget build(BuildContext context) {
  return CupertinoPageScaffold with
    SafeArea(top: false, bottom: false) with
    ListView(
      children: [
        SizedBox(height: 200.0) with
        ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 10,
          itemExtent: 160.0,
          itemBuilder: (context, index) {
            return Padding(padding: const EdgeInsets.only(left: 16.0)) with
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: relatedColors[index],
                ),
              ) with
              Center with
              CupertinoButton(
                child: const Icon(
                  CupertinoIcons.plus_circled,
                  color: CupertinoColors.white,
                  size: 36.0,
                ),
                onPressed: () { },
              );
          },
        ),
      ],
    );
}
```

Another use case this would hit is "block-like" APIs like the test package where
you pass a big function literal to a method. It's annoying to wrap the entire
function in parentheses and mix it in with the argument list. This would let you
hoist it out:

```dart
void main() {
  group('flutter gallery transitions') with () {
    FlutterDriver driver;
    setUpAll with () async {
      driver = await FlutterDriver.connect();
    };

    tearDownAll with () async {
      if (driver != null)
        await driver.close();
    };

    test('navigation') with () async {
      await driver.tap(find.text('Material'));

      final demoList = find.byValueKey('GalleryDemoList');
      final demoItem = find.text('Text fields');
    };
  };
}
```

I'm not sure if `with` reads well. Another option is `on`. Or it might be
better to have some prefix notation.

Pros:

- Semantically and syntactically simple.
- Somewhat familiar to people who know Python decorators.
- Useful for the other common case of passing a big function literal to a
  function.

Cons:

- Only covers a fairly limited use case.
- In Python, `@` decorates *declarations*, here we are wrapping *expressions*.
- Unusual?
- Formatting well might be difficult.

### See also

- [Decorator proposal for ECMAScript](https://medium.com/google-developers/exploring-es7-decorators-76ecb65fb841)
