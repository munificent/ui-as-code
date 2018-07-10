A handful of places in the grammar take a comma-separated series of things:

- A positional argument list. Each element is an expression of heterogeneous
  type.
- List literal. Each element is an expression of the same type.
- Named argument list. Each element is a "name: expression" pair of
  heterogeneous type.
- Map literal. Each element is a "expression: expression" pair of homegeneous
  type.

(There are parameter lists too, but those are declarations, not executed code,
so we'll ignore them.)

Sometimes, you really wish you could do a bit of imperative control flow in
those. In particular:

- Sometimes it would be nice to conditionally omit one or more elements.
- Or maybe you want to choose between one or another element.
- Or you'd like to insert a series of elements or compute a series of them.

Here's a somewhat contrived example based on
flutter/examples/flutter_gallery/lib/demo/pesto_demo.dart:

```dart
Table(
  children: [
    TableRow(
      children: [
        TableCell(child: Image.asset(recipe.ingredientsImagePath)),
        TableCell(child: Text(recipe.name, style: titleStyle)),
      ]
    ),
    TableRow(
      children: [
        const SizedBox(),
        Text(recipe.description),
      ]
    ),
    TableRow(
      children: [
        const SizedBox(),
        Text(recipe.nutrition),
      ]
    ),
    TableRow(
      children: [
        const SizedBox(),
        Text('Ingredients'),
      ]
    ),
  ]..addAll(recipe.ingredients.map(
    (RecipeIngredient ingredient) {
      return _buildItemRow(ingredient.amount, ingredient.description);
    }
  ))..add(
    TableRow(
      children: [
        const SizedBox(),
        Text('Steps', style: headingStyle),
      ]
    )
  )..addAll(recipe.steps.map(
    (RecipeStep step) {
      return _buildItemRow(step.duration ?? '', step.description);
    }
  )),
);
```

Further, let's say we want to swamp out the nutrition row on Saturdays (that's
our cheat day). This example is actually pretty good already. The author has
pushed the language to its limit using cascades, `add()`, `addAll()`, `map()`,
and a helper function to try to keep the whole table in a single big expression.

Often, users resort to building up the lists imperatively before passing it to a
widget.

The idea here is, roughly, to allow "if" and "for" inside element lists. That
gives you something like:

```dart
Table(
  children: [
    TableRow(
      children: [
        TableCell(child: Image.asset(recipe.ingredientsImagePath)),
        TableCell(child: Text(recipe.name, style: titleStyle)),
      ]
    ),
    TableRow(
      children: [
        const SizedBox(),
        Text(recipe.description),
      ]
    ),
    if (isSaturday)
      TableRow(
        children: [
          const SizedBox(),
          Text(recipe.nutrition),
        ]
      )
    TableRow(
      children: [
        const SizedBox(),
        Text('Ingredients'),
      ]
    ),
    for (var ingredient in recipe.ingredients)
      _buildItemRow(ingredient.amount, ingredient.description),
    TableRow(
      children: [
        const SizedBox(),
        Text('Steps', style: headingStyle),
      ]
    ),
    for (var step in recipe.steps)
      _buildItemRow(step.duration ?? '', step.description);
  ],
);
```

Here's more precisely what I have in mind:

## if

An `if` element lets you conditionally include an element, or choose between one
of two if an `else` clause is provided. It is *not* a statement. The "body"
clause is an element of the appropriate grammatical type for the containing
series: expression for a list literal, "name: expression" pair for a named
argument list, "expression: expression" pair for a map literal.

When the condition evaluates to true, the body is evaluated and inserted into
the element sequence. If false, the else clause is inserted if there is one. For
named arguments, not evaluating a body means the argument isn't passed at all.
Likewise for maps, the key is not inserted at all.

Supporting this for positional argument lists is weirder. We don't want an
omitted argument to shift up the others because that interferes with statically
type-checking the arguments. We could say that the else clause is required, or
maybe that an omitted "else" means you get `null` for the argument.

## for

A `for` element lets you imperatively insert zero or more elements into the
series. Again, not a statement. The body is an element of the expected type. The
iterator expression is evaluated and then the iterator is run until it runs out
elements. At each iteration, the body is evaluated and the result is inserted
into the element sequence at that point.

Both of these can nest since the body of each is itself an element. You could do
comprehension-like stuff like:

var cartesianProduct = [
  for (var row in rows)
    for (var column in row.column)
      if (column != null) column
];

## Others

We should probably do C-style `for` loops and `while` loops as well. I guess
even `do-while`.

## Braces

My main fear with this idea is that users will expect the body of these
statement-ish things to actually be statements. And further, they may expect to
be able to put any statement in a context where an element is expected.

Allowing any *statement* means expression statements, and then we have to worry
about which expression statements have their result discarded versus yielded
into the surrounding element sequence. It also looks really weird to have a bare "argName: value" pair where you expect to see a statement.

And it means dealing with both commas *and* semicolons, mixed together. Ick.

I'm trying to dodge that here by saying the bodies of `if` and `for` in this context are *not* statements. But if users *do* want the full statement grammar, one option would be to let them use a braced block:

```
var tableCells = [
  yield* headers;
  for (var row in rows) {
    for (var column in row.column) {
      if (column != null) yield column;
    }
  }
];
```

Inside that, you're back in full statement land. You can declare variables, call
methods, whatever. But the trade-off is that when you do want to emit an element
into the sequence, you must do so explicitly using `yield` or `yield*`.

It's roughly as if the block is an implicit, immediately-invoked `sync*`
function. Not exactly, though, for a couple of reasons:

- We'd probably disallow `yield*` inside a named argument sequence. It's not
  like we have record types.

- In a map literal, we could have `yield` either expect a map, or give it some
  special `yield key: value;` syntax.

- When a block is used inside an `if` element for a positional argument list,
  we'd need to ensure you never yield more than one element.
