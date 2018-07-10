**Note: This is semantically identical to the "decorators" idea, but uses
different syntax and is inspired by a different feature from other languages.**

While we talk about Flutter code as being big *trees* of expressions, in many
cases, it's really a linear nested chain. Here's an example:

```dart
Positioned(
  top: statusBarHeight,
  left: 0.0,
  child: IconTheme(
    data: const IconThemeData(color: Colors.white),
    child: SafeArea(
      top: false,
      bottom: false,
      child: IconButton(
        icon: const BackButtonIcon(),
        tooltip: 'Back',
        onPressed: () {
          _handleBackButton(appBarMidScrollOffset);
        }
      ),
    ),
  ),
)
```

([Source](https://github.com/flutter/flutter/blob/master/examples/flutter_gallery/lib/demo/animation/home.dart#L607-L624))

There are child widgets three levels deep. That sequence of widgets is what the
reader cares about, but they're buried in noise.

[Several languages have a "pipeline" operator][pipeline], usually written `|>`.
It takes the operand on the left and passes it to the function on the right. So
`foo |> bar` is equivalent to `bar(foo)`. This doesn't seem super useful, but it
lets you compose functions such that they read left to right in the order that
they are evaluated.

[pipeline]: https://github.com/tc39/proposal-pipeline-operator

Consider a similar "backflow" operator, `<|`. It works in the opposite
direction. It takes the operand on the right, and passes it to the function the
left. If the function on the left is already given arguments, it adds the
operand to the end of the argument list. So `foo(1) <| 2` is equivalent to
`foo(1, 2)`.

What's the point? The operands are already in left-to-right order? Having this
would let us hoist the child widgets out of the nested parentheses and flatten
them. If we also assume that the "child" named parameters become positional and
that we all passing positional arguments after named ones, then the above code
can be turned into:

```dart
Positioned(top: statusBarHeight, left: 0.0)
<|IconTheme(const IconThemeData(color: Colors.white))
<|SafeArea(top: false, bottom: false)
<|IconButton(
  icon: const BackButtonIcon(),
  tooltip: 'Back',
  onPressed: () {
    _handleBackButton(appBarMidScrollOffset);
  }
)
```

We lose three levels of indentation. Also, moving the large child widgets out of
the argument lists leaves the remaining argument lists small enough to fit on a
single line in most cases. Where the original code is 19 lines, the new code is
9.

This also makes it easier to rearrange the nested widgets. Cutting a single line
or commenting it out removes a widget from the chain but leaves the rest alone.
Placing the `<|` at the beginning of the next line instead of the end of the
previous line helps with that and makes it easier to see which lines are
subordinate to a previous one when skimming down the page.
