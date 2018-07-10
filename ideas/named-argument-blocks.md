This is essentially Yegor's proposal, which hasn't been shared publicly yet.
Sketching it out here as a reminder and because many other ideas interact with
it.

The basic idea is that after some callable entity, you have a braced block.
Inside that block, the named parameters to the invocation are in scope as
variables you can assign to. Otherwise, it works just like a block &mdash; it
can have arbitrary statements, local variables, control flow, etc. The body is
executed before the invocation. Any named parameter variables that are assigned
get passed to the invocation.

The key feature is that allowing control flow statements gives you a way to
conditionally pass arguments or not.

So this:

```dart
Widget build(BuildContext context) {
  IconButton button;
  if (isWindows) {
    button = IconButton(
      icon: Icon(Icons.menu),
      tooltip: 'Navigation menu',
    );
  } else {
    button = IconButton(
      icon: Icon(Icons.menu),
      tooltip: 'Navigation menu',
      padding: const EdgeInsets.all(20.0),
    );
  }

  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    child: button,
  );
}
```

Turns into something like:

```dart
Widget build(BuildContext context) {
  return Container {
    height = 56.0;
    padding = const EdgeInsets.symmetric(horizontal: 8.0);
    decoration = BoxDecoration(color: Colors.blue[500]);
    child = IconButton {
      icon = Icon(Icons.menu);
      tooltip = 'Navigation menu';
      if (!isWindows) padding = const EdgeInsets.all(20.0);
    };
  };
}
```

Note how we no longer need to hoist out the IconButton. Instead, we can use an
inner if statement to decide whether or not to pass the padding argument.

Overall, I really like the syntax and semantics of this. Blocks and local
variables are already well understood by users. The proposed semantics have, I
think, a natural and straightforward desugaring. It just looks nice.

My main concern is that it doesn't go far enough and solve more of the problems.
The trailing block syntax is a very valuable chunk of grammar (several other
languages use it for other purposes) so we should get as much mileage out of it
as we can. That could mean extending it to support vararg-like use cases,
something like Kotlin's builders, or other features. All of those extensions are
much trickier than the basic proposal here, though.

Two less significant concerns are:

- Converting from regular named arguments to this notation is a chore. You need
  to replace the `:` with ` = `, and replace the `,` with `;`. Optional
  semicolons help a little with the latter, but the former is just tedious.

- It's not clear when a user should prefer each form. Obviously, if you need to
  conditionally omit an argument, you want this new notation. But what about
  other cases? A lack of good guidance makes the previous concern worse because
  it means users are more likely switch between the two forms as their whims or
  needs change.

I don't think either of those are fatal blows, though.

## Mixed argument lists

An open question is whether a regular argument list can also be provided. Is
this kosher:

```dart
Widget build(BuildContext context) {
  return Container(height: 56.0) {
    padding = const EdgeInsets.symmetric(horizontal: 8.0);
    decoration = BoxDecoration(color: Colors.blue[500]);
    child = IconButton(icon: Icon(Icons.menu)) {
      tooltip = 'Navigation menu';
      if (!isWindows) padding = const EdgeInsets.all(20.0);
    };
  };
}
```

It would be very useful for APIs where you have some *positional* arguments to
pass. But does it also extend to named arguments? If so, what is the guidance
for which arguments to put between the parens versus in the block?

## Local functions

It's pretty common to pass lambdas as named arguments:

```dart
FlatButton {
  child = Text("Regret");
  onPressed = () {
    Navigator.of(context).pop();
  };
)
```

This proposal supports that, but the `=` between the name and function looks a
little funny. A possible extension, [similar to what Ceylon does][ceylon], would
be to support something more like local function declaration syntax:

[ceylon]: https://ceylon-lang.org/documentation/1.2/tour/named-arguments/#declarative_object_instantiation_syntax

```dart
FlatButton {
  child = Text("Regret");
  onPressed() {
    Navigator.of(context).pop();
  }
)
```

Note that no semicolon is needed after the function body, which is a common
source of errors. (Of course, optional semicolons fix that too.)

The main challenge is that local function declarations are already valid
statements, so repurposing that exact syntax to mean something different can be
confusing and make it harder to move code in and out of one of these blocks.

That feels risky to me to save, essentially, two punctuation characters.
