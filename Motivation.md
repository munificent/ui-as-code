One of the most powerful features of Flutter is that user interface is defined
using Dart code. That gives you access to the full features of the language. All
the tools Dart gives you for abstraction, code reuse, and maintainability now
apply to your UI layout too.

It looks something like this:

```dart
Widget build(BuildContext context) {
  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    child: Row(
      children: [
        IconButton(
          icon: Icon(Icons.menu),
          tooltip: 'Navigation menu',
        ),
        Expanded(
          child: title,
        ),
        IconButton(
          icon: Icon(Icons.search),
          tooltip: 'Search',
        ),
      ],
    ),
  );
}
```

It works pretty well given that Dart's syntax is based on C which was created
almost 50 years ago within the limitations of single-pass compilation on a
PDP-11. Even Dart's own syntactic extensions weren't designed with expressions
this large and deep in mind&mdash;DSLs weren't a goal for Dart like they were
Smalltalk, Lisp, Groovy, or Kotlin.

But, as users build larger and larger widgets in Flutter, Dart's syntax doesn't
help them express themselves as well as it could. Before we get into solutions,
I want to break down the frictions in using the current Dart expression syntax
for building big deep trees of objects.

When it comes to syntax and usability issues, it's hard to cleanly separate a
problem or feature into orthogonal components. It's a holistic sort of thing. So
you'll see a lot of overlap in the problems below. Think of it as coming at the
whole problem from different angles more than distinct problems to solve
separately.

I use Flutter as the motivating example framework here because they are the
biggest customer and the place where the pain is most acutely felt. But the
problems described apply to any framework or library that uses Dart expressions
to build nested trees of objects or calls. Any solution we devise should work
well for those libraries too.

## Conditionally omitting content

I'm listing this problem first because I think it causes the largest pain to
users when they run into it. Where the other problems are more like
friction&dash;some sand on your beach blanket&dash;this one is an unexpected
gust that blows your umbrella away.

Consider the first example up there. It's a big blob of code, but it's almost
declarative. The nesting structure correctly reflects the organization of the
UI. Reading it from top down walks through how the UI is built. Great.

Then you discover that on Windows, it looks wrong. It turns out you don't want
to pass the explicit `padding` for `IconButton` and instead want to use the
default there. Note that passing an explicit `null` is *not* the same as
omitting the argument entirely, so you can't do something like:

```dart
padding: isWindows ? null : const EdgeInsets.all(20.0),
```

Treating a `null` as distinct from not passing it at all isn't great API design,
but it does happen. Even in cases where you can pass `null` to indicate the
absence of a parameter, there's only so much code one can reasonably jam into a
`? <stuff...> : null` conditional expression.

Instead, to conditionally omit a parameter, you end up rearranging your program
significantly:

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
    child: Row(
      children: [
        button,
        Expanded(
          child: title,
        ),
        IconButton(
          icon: Icon(Icons.search),
          tooltip: 'Search',
        ),
      ],
    ),
  );
}
```

Some of the code is now inverted where a child widget appears before the outer
widgets that contain it. There is redundancy between the two branches of the if
for all of the other parameters, and it's hard to visually diff the two sides
to see what's actually different.

A similar problem occurs in lists. Let's also say that on Android, we want to
omit the search `IconButton`. There's no way to conditionally omit an item in a
list literal, so again the code much be reorganized:

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

  List<Widget> buttons = [
    button,
    Expanded(
      child: title,
    ),
  ];

  if (!isAndroid) {
    buttons.add(IconButton(
      icon: Icon(Icons.search),
      tooltip: 'Search',
    ));
  }

  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    child: Row(
      children: buttons,
    ),
  );
}
```

The resulting code is even more inverted, almost bottom-up at this point. It's
difficult, when looking at the code, to get a sense of the resulting tree
structure of the UI, especially across the various platforms.

Also, it took a non-trivial amount of work to do this reorganization. What is
conceptually a small change "omit this part on this condition" requires a large
code motion. If the condition later goes away, will the maintainer remove all of
the now-unneeded imperative code and collapse it back to its earlier declarative
form, or just leave it unnecessarily bottom-up?

## Long strings of hard-to-read closing delimiters

This is one of the first things most [Flutter users notice][tweet] that's a
little funny about their UI code. An obvious consequence of deep nesting is deep
*un*-nesting at the end:

[tweet]: https://twitter.com/tristan2468/status/997506133802782722

```dart
CupertinoTabScaffold(
  tabBuilder: (BuildContext context, int index) {
    return CupertinoTabView(
      builder: (BuildContext context) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text('Page 1 of tab $index'),
          ),
          child: Center(
            child: CupertinoButton(
              child: const Text('Next page'),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute<Null>(
                    builder: (BuildContext context) {
                      return CupertinoPageScaffold(
                        navigationBar: CupertinoNavigationBar(
                          middle: Text('Page 2 of tab $index'),
                        ),
                        child: Center(
                          child: CupertinoButton(
                            child: const Text('Back'),
                            onPressed: () { Navigator.of(context).pop(); },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  },
)
```

[(source)](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/cupertino/tab_scaffold.dart#L30)

There's fourteen lines here&mdash;almost half of the code&mdash;that do nothing
but terminate argument lists and functions. The lines themselves aren't
necessarily a problem. It's that the depth of the nesting means the
corresponding *opening* delimiter may now be far away from its other half,
possibly scrolled offscreen. It's hard to tell which expression a `)`, `]`, or
`}` belongs to. If you want pass another argument to, say,
`CupertinoPageScaffold()`, how long does it take you to figure out where to
insert it?

The VS Code and IntelliJ plug-ins for Dart help by drawing little
pseudo-comments at the end of the lines to tell you which expression each `)`
belongs to:

```dart
...
                          child: CupertinoButton(
                            child: const Text('Back'),
                            onPressed: () { Navigator.of(context).pop(); },
                          ), // Center
                        ), // CupertinoPageScaffold
                      );
                    },
                  ), // CupertinoPageRoute
                ); // push
              },
            ), // CupertinoButton
          ), // Center
        ); // CupertinoPageScaffold
      },
    ); // CupertinoTabView
  },
) // CupertinoTabScaffold
```

This is great for people reading code inside those IDEs, but doesn't help people
using other editors, doing code reviews, or reading code on GitHub.

## Extra nesting and boilerplate for child widgets

In the above example, each nested widget is a single child. Many widgets contain
a series of children. In that case, those children are typically passed by
wrapping them in a list literal:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      child: ListView(
        children: [
          Column(
            children: [
              RadioListTile(
                title: const Text('Value'),
                onChanged: (value) {
                  setState(() {
                    selectedLogEnumValue = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

The list literal adds more punctuation and an extra level of indentation. Note
that the `RadioListTile` object is nested *two* levels inside its direct parent,
`Column`. The two list literals here add two extra levels of indentation and
four mostly-useless lines of code.

The named argument `children:` doesn't add much value either. It doesn't tell
you *what* those children represent. It's mostly there because of limitations in
Dart around mixing named and positional arguments.

Even in the single child case, the named argument isn't very helpful:

```dart
Container(
  child: ListView(...),
)
```

What does "child" tell us here that wasn't obvious from the fact that the `ListView` is nested inside the `Container`?

The solution is not as simple as removing the parameter names any time you nest
widgets. There are widgets that have multiple logical "child" or "children"
parameters with useful, distinct names:

```dart
ListTile(
  leading: const Icon(Icons.flight_land),
  title: const Text('Trix\'s airplane'),
  subtitle: _act != 2 ? const Text('The airplane is only in Act II.') : null,
  enabled: _act == 2,
  onTap: () { /* react to the tile being tapped */ }
)
```

There are three arguments here whose values are inner widgets, `leading`,
`title`, and `subtitle`. Each argument means something different and is
optional. So sometimes you do need distinct names. But in case where "child" or
"children" is used, the word is just noise.

## Lots of punctuation to get right (or wrong)

Argument lists are surrounded by parentheses, but parentheses are also used for
grouping in expressions. If you see square brackets, it's probably a list
literal, though it could be a subscript operator. Curly braces could be a
function body (function expressions for event handlers are common inside
widgets), a block nested inside a function, or a map literal. When scanning
code, the brackets don't help you get your bearing.

In an argument list or collection literal, you must have a single comma between
each item or the compiler yells at you. You get to choose whether to put a comma
*after* the last item. If you add one, dartfmt puts each parameter on its own
line. If you don't, it tries to pack them more compactly. Each is the right
choice in some cases:

```dart
Padding(
  padding: const EdgeInsets.only(top: 24.0),
  child: RichText(
    text: TextSpan(
      children: [
        TextSpan(
          style: aboutTextStyle,
          text: 'Flutter ...',
        ),
        TextSpan(
          style: aboutTextStyle,
          text: '.',
        ),
      ],
    ),
  ),
)
```

Most of the argument lists have trailing commas here, but note that
`EdgeInsets.only()` does not. If you later change that code to:

```dart
const EdgeInsets.only(
  top: 24.0,
  bottom: 12.0,
)
```

Then you probably do want to add the trailing comma. Or not? If you remove one
of those parameters, you probably want to remove the trailing comma too.
Basically, you have to think about how you want each argument list formatted and
choose the trailing comma appropriately.

Meanwhile, inside a block or function body, each statement needs a semicolon
after it. Except block statements themselves, which don't have a semicolon at
the end.

This punctuation is visually noisy and error-prone. If you get it wrong,
sometimes you get a compile error, or sometimes dartfmt doesn't do what you want
to your code.

## Hard to work with expression sequences

A consequence of the above is that moving code around is error-prone. The rule
to always put a trailing comma after each argument or collection element helps.
When each argument or element is on its own line, you can usually cut and paste
entire lines to rearrange things.

But if the argument list has a single item, sometimes you don't want it on its
own line and you don't want a trailing comma. So you gain some flexibility in
some cases, but in return have to worry more about manually controlling
line-breaking.

If you take an argument and hoist it up to a local variable, you need to
remember to strip the comma off the end of the line and replace it with a
semicolon:

```dart
var header = TextSpan(
  style: aboutTextStyle,
  text: 'Flutter ...',
), // <-- Oops! Must be ";" now.

Padding(
  padding: const EdgeInsets.only(top: 24.0),
  child: RichText(
    text: TextSpan(
      header,
      children: [
        TextSpan(
          style: aboutTextStyle,
          text: '.',
        ),
      ],
    ),
  ),
)
```

Cutting the whole line isn't sufficient. This exacerbates the pain caused by the
first problem in this list where you *do* find yourself needing to hoist
subexpressions out into variables sometimes to conditionally modify parameters
or child widets.

## Inefficient use of horizontal space

In order to mitigate the previous problem, most idiomatic Flutter code puts each
argument is on its own line, a trailing comma after the last argument, and the
closing delimiter on the next line. (In some cases, the argument list does not
get a trailing comma and is all on one line. It's not clear what the rules for
when to do this are.)

That helps, but in return it means the code doesn't use horizontal space as
well. In many cases, an argument list could easily fit on one line, and would
still be easy to read if it were.

Most would probably prefer this:

```dart
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Center(
        child: Column(
          children: [
            Icon(choice.icon, size: 128.0, color: textStyle.color),
            Text(choice.title, style: textStyle),
          ],
        ),
      ),
    );
  }
```

Over:

```dart
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Center(
        child: Column(
          children: [
            Icon(
              choice.icon,
              size: 128.0,
              color: textStyle.color,
            ),
            Text(
              choice.title,
              style: textStyle,
            ),
          ],
        ),
      ),
    );
  }
```

Packing the arguments onto a single line fits more code onto the users screen
and reduces the problem where a closing bracket is far away from the
corresponding opening one.

Of course, you can certainly go too far. The goal isn't to eliminate all
whitespace. But it seems that `build()` methods in Flutter don't take enough
advantage of horizontal space and are outside of the sweet spot for readability.

In a corpus of code formatted not using Flutter's one-argument-per-line rule,
the average line was 29.37 characters and the median was 28. In Flutter example
code outside of `build()` methods, it's an average of 29.08 and a median of 25.
Inside `build()` methods, it's an average of 21.05 and median of 17. Even if we ignore the lines that only contain a `)` in the `build()` methods, the average is still 25.69 and the median 21. &dagger;

```
                                       total  average  median
flutter/example/ build()                6705    21.05      17
flutter/example/ non-build()           13813    29.08      25
dart/sdk/pkg/                         924678    29.37      28
flutter/example/ build() w/o ")"        5397    25.69      21
flutter/example/ non-build() w/o ")"   12949    30.90      27
```

If we assume the non-`build()` code is typical and users are happy with that, it
seems the `build()` methods aren't taking good advantage of the available space.

<small>&dagger; This considers all non-empty, non-comment lines, and strips them
of leading and trailing whitespace and indentation. The non-Flutter corpus is
the Dart SDK's `pkg/` directory. The Flutter corpus the `example/` directory in
the main Flutter repo. Ignoring ")" means discarding lines are `)`, `),`, or
`);`. Calculated using `scripts/bin/horizontal_space.dart`.</small>

## Not friendly to automated formatting

This "problem" is a little hand-wavey. Users working with Dart do so in the
context of dartfmt. The goal is that they rarely need to think about formatting
and never need to manually apply it. When reading code, it is consistently
formatted to the same excellent style.

The "excellent" part is hard. Dartfmt does its best, but it does not understand
what your code actually means. In fact, it needs to be able to run on code that
may be full of type errors or other non-syntax problems&mdash;often the *first*
step to fixing up some broken code is to reformat it.

The most readable way to format a piece of code may depend on what kind of code
it is. The ideal style for a declarative tree of UI widgets may be different
from a chunk of imperative, procedural code. If we use the exactly same syntax
for both, then dartfmt has no syntactic hints to tell which kind of code it's
looking at so it can pick the best style for each.

On the other hand, if the grammar exposes different syntax features to use for
those kinds of code, dartfmt use that as a hook to format each in a way that
makes the most sense for that domain. In general, the language syntax, API
design, and formatting tools should work harmoniously together to free users
from having to worry about whitespace.

## Summary

These are the main pain points I see:

*   Inside an argument list or collection literal, there is no easy way to
    conditionally omit elements, repeat them, or choose between different
    options. Expressions don't give users the power that statements and control
    flow naturally provide.

*   It's hard to know where you are in a long list of closing delimiters.

*   Expression syntax is a slurry of punctuation that is tedious to maintain and
    easy to get wrong.

*   Working with sequences of subexpressions is fussy, forces users to mess with
    formatting, and still doesn't use the available space well.
