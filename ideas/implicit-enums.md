A common complaint with Flutter is that when you have an argument whose type is
an enum, passing it looks redundant:

```dart
new TableRow(
  children: [
    TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Image.asset(
        recipe.ingredientsImagePath,
        package: recipe.ingredientsImagePackage,
        width: 32.0,
        height: 32.0,
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown
      )
    ),
    TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Text(recipe.name, style: titleStyle)
    ),
  ]
)
```

Here, these arguments feel repetitive:

- `verticalAlignment: TableCellVerticalAlignment.middle`
- `alignment: Alignment.centerLeft`
- `fit: BoxFit.scaleDown`

The obvious solution would be to say that if a parameter's type is an enum type,
then you can reference the enum name directly. However, because enums are quite
limited in Dart, many "enums" are actually user-defined classes with const
static members for the enum cases. In the example here, [Alignment][] is not an
actual Dart enum.

[alignment]: https://docs.flutter.io/flutter/painting/Alignment-class.html

In practice, it is also fairly common to change an enum type into a class when
more functionality is later needed. If we scope this feature to only true enums,
that becomes a breaking change.

Here's a pitch then: in a downwards inference context of type `T`, static
getters and constants of type `T` defined on `T` are implicitly added to the
scope where `T` is declared.

**TODO: Maybe allow subtypes of `T` too?**

That changes the example to:

```dart
new TableRow(
  children: [
    TableCell(
      verticalAlignment: middle,
      child: Image.asset(
        recipe.ingredientsImagePath,
        package: recipe.ingredientsImagePackage,
        width: 32.0,
        height: 32.0,
        alignment: centerLeft,
        fit: scaleDown
      )
    ),
    TableCell(
      verticalAlignment: middle,
      child: Text(recipe.name, style: titleStyle)
    ),
  ]
)
```

## Scope and shadowing

The "to the scope where `T` is declared" part is to resolve this ambiguity:

```dart
enum Suit { club, diamond, heart, spade }

expectSuit(Suit suit) {}

main() {
  var spade = "my shovel";
  expectSuit(spade);
}
```

Here, `spade` could refer to either the local variable or the enum case. I think
users would be surprised if an identifier declared at the top level of a program
shadowed a local variable. Also, if the local variable was what you wanted,
there is no way to access it.

If we disambiguate by preferring the local variable, you can always access the
enum case by fully qualifying it (`Suit.spade`). Also, I believe placing the
enum names in the outer scope where the class is declared or imported minimizes
the chances of this being a breaking change.

We'd probably want to refine the rule to state that if there is already a name
in that scope, then the enum member name is not implicitly added.

## Other contexts

In the examples here, I'm using parameters as the context where the enum cases
are inferred but it should hopefully work anywhere downwards inference kicks in:

```dart
Suit returnType() => club;

variableDeclaration() {
  Suit suit = club;
}

switchCase(Suit suit) {
  switch (suit) {
    case club: // ...
    case diamond: // ...
  }
}
```

This feature *seems* fairly straightforward, but it's a large step for the
language to take. It means we are using the static type system and type
inference to affect name resolution. Up to now, those two are totally decoupled
&mdash; you can resolve all bare identifiers in Dart without knowing *anything*
about the static types.

This means that, for example, changing the type of a member can cause an
identifier to no longer resolve or resolve to something different. It means that
tweaks to type inference could cause breaking changes to existing code because
of how they affect name resolution.

So we should be *really* cautious about going in this direction. If we do
extension methods, then it becomes part of a larger trend in how the language
works. But on it's own, it couples two up-to-now orthgonal parts of the
language.

**TODO: Note that this lets you use, say `april` anywhere a DateTime is expected.**

**TODO: This is a breaking change if the names shadow inherited members.**

```dart
class A {
  get foo => Enum("A.foo");
}

class B extends A {
  method() {
    Enum enum = foo;
  }
}

class Enum {
  static const foo = const Enum("Enum.foo");

  final String name;
  const Enum(this.name);
}
```
