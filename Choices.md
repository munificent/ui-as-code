I have a couple of proposals in progress for "UI as code": [Parameter Freedom][]
and [Spread Collections][]. Those cover some of the [goals][] around improving
UI code. Mixing positional and named arguments lets `child` parameters become
positional. Rest parameters eliminate the boilerplate `children: [ ... ]` code.
One of the biggest remaining challenges is [conditionally omitting or swapping
out arguments and child widgets][cond].

[parameter freedom]: https://github.com/munificent/ui-as-code/blob/master/in-progress/parameter-freedom.md
[spread collections]: https://github.com/munificent/ui-as-code/blob/master/in-progress/spread-collections.md
[goals]: https://github.com/munificent/ui-as-code/blob/master/Motivation.md
[cond]: https://github.com/munificent/ui-as-code/blob/master/Motivation.md#p1-conditionally-omitting-content

Say you have:

```dart
Widget build(BuildContext context) {
  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    Row(
      IconButton(
        icon: Icon(Icons.menu),
        tooltip: 'Navigation menu',
        padding: const EdgeInsets.all(20.0),
      ),
      Expanded(child: title),
      IconButton(icon: Icon(Icons.search), tooltip: 'Search')
    ),
  );
}
```

If you want to omit the navigation menu padding (a named parameter) on Windows
and the search button on Android (a rest parameter or list element), you have to
contort that code into:

```dart
Widget build(BuildContext context) {
  IconButton button;
  if (isWindows) {
    button = IconButton(icon: Icon(Icons.menu), tooltip: 'Navigation menu');
  } else {
    button = IconButton(
      icon: Icon(Icons.menu),
      tooltip: 'Navigation menu',
      padding: const EdgeInsets.all(20.0),
    );
  }

  List<Widget> buttons = [button, Expanded(child: title)];

  if (!isAndroid) {
    buttons.add(IconButton(icon: Icon(Icons.search), tooltip: 'Search'));
  }

  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    child: Row(children: buttons),
  );
}
```

This is a large code change for a small conceptual change. The resulting code
no longer structurally matches the UI it builds.

## Three Paths

To address that issue, I've looked at three broad approaches we could take. I've
spent a ton of time trying to work through details on each path and see which
one is best. Unfortunately, none is universally better than the others. Each
involves trade-offs. Since no single one is dominates, I think the best way to
evaluate them is against each other.

To that end, I'll *very roughly* sketch out each here. They are extremely
hand-wavey but try to fill in the blanks as best you can. The details shouldn't
matter for the overall intent of this doc.

### [Control flow elements][]

[control flow elements]: https://github.com/munificent/ui-as-code/blob/master/ideas/control-flow-elements.md

This is the smallest (and worst named) proposal. Three places in Dart expect a
comma-separated sequence of "elements" of some kind. In a function call, the
elements are named, positional, and spread arguments. A list literal's elements
are expressions. A map literal's elements are `key: value` pairs.

In all three places, we extend Dart to allow `if (expression)` followed by an
element:

```dart
function(
  arg1,
  if (isTuesday) arg2,
  arg3,
  if (isTuesday) named: arg4
);

var list = [
  item1,
  if (isTuesday) item2,
  item3
];

var map = {
  key1: value1,
  if (isTuesday) key2: value2,
  key2: value3
};
```

You can also provide an `else` clause if you want:

```dart
function(if (isTuesday) thenArg else elseArg);
```

If you want to guard multiple elements on the same condition, you can use a
comma-separated series of elements wrapped in parentheses:

```dart
function(
  arg1,
  if (isTuesday) (arg2, anotherArg),
  arg3
);
```

If the condition evaluates to true, the elements in the then clause are
evaluated and inserted in the argument list or collection literal. Otherwise,
they are omitted and the else clause is used instead, if present. This gets
weird for positional arguments since omitting one would change the position of
later arguments. To keep that sane, this syntax is only allowed for rest
arguments.

We also allow `for`:

```dart
var source = [1, 2, 3];
var result = [1, for (var i in source) i + 1, 5]; // [1, 2, 3, 4, 5].
```

It expands to as many elements as produced by the iteration. A single-element
list using `for` comes passably close to the list comprehension syntax of some
other languages:

```dart
var numbers = [for (var i = 0; i < 10; i++) i];
var squares = [for (var i in numbers) i * i];
```

The `if` and `for` elements can also be nested arbitrarily. No other control
flow constructs are allowed.

With this proposal, the example becomes:

```dart
Widget build(BuildContext context) {
  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    Row(
      IconButton(
        icon: Icon(Icons.menu),
        tooltip: 'Navigation menu',
        if (!isWindows) padding: const EdgeInsets.all(20.0),
      ),
      Expanded(child: title),
      if (!isAndroid) IconButton(icon: Icon(Icons.search), tooltip: 'Search')
    ),
  );
}
```

It's identical to the original code except for the two `if (...)` clauses.

#### Pros

*   **This is the simplest of the three options**, by a large margin. There's
    less to specify, implement, and test. There's less new syntax and semantics
    for users to learn.

*   **The code is terse in common use cases.** Even though limited, it does
    cover the use cases I know we have based on looking at a lot of Flutter
    code.

#### Cons

*   **It's potentially in the uncanny valley.** It looks like familiar if and
    for statements, but they aren't actually *statements*. The fact that the
    body is an element and not a statement might throw users off.

### [Argument initializer blocks][]

[argument initializer blocks]: https://github.com/munificent/ui-as-code/blob/master/ideas/named-argument-blocks.md

This idea was initially proposed by Yegor Jbanov. We allow a curly-braced block
to follow some invocable entity: a class, constructor name, or function. The
body is a normal Dart block. You can use whatever statements, control flow, etc.
that you want:

```dart
IconButton {
  print("I'm a block");
}
```

The special part is that named parameters of the thing being called are
implicitly in scope as local variables. Assigning to these causes the
corresponding parameter to have the given argument value:

```dart
IconButton {
  icon = Icon(Icons.menu);
  tooltip = 'Navigation menu';
  padding = const EdgeInsets.all(20.0);
}
```

By putting these assignments inside regular if statements, you can omit them.

```dart
IconButton {
  icon = Icon(Icons.menu);
  tooltip = 'Navigation menu';
  if (!isWindows) padding = const EdgeInsets.all(20.0);
}
```

The main challenge is to extend this to handle unnamed entities. For lists of
child widgets or other open-ended sequences, we need to be able to handle
conditions in rest arguments and list literals. I've sunk a lot of time into
this and still haven't found a great answer. The best I've come up with is:

```dart
Row {
  yield IconButton(icon: Icon(Icons.menu), tooltip: 'Navigation menu');
  yield Expanded(child: title);
  yield IconButton(icon: Icon(Icons.search), tooltip: 'Search');
}
```

Here, `yield` appends a value to the rest parameter of the called function or
constructor. It works, but it's kind of imperative and verbose. Given that, the
full example looks like this:

```dart
Widget build(BuildContext context) {
  return Container {
    height = 56.0;
    padding = const EdgeInsets.symmetric(horizontal: 8.0);
    decoration = BoxDecoration(color: Colors.blue[500]);
    child = Row {
      yield IconButton {
        icon = Icon(Icons.menu);
        tooltip = 'Navigation menu';
        if (!isWindows) padding = const EdgeInsets.all(20.0);
      };
      yield Expanded(child: title);
      if (!isAndroid) {
        yield IconButton(icon: Icon(Icons.search), tooltip: 'Search');
      }
    };
  };
}
```

I've somewhat arbitrarily switched some of the Widget constructors to use the
new block syntax, but not all of them.

#### Pros

*   This is subjective, but I and others I've talked to think **it just looks
    really nice.** [Ruby][], [Groovy][], [Scala][], [Kotlin][], and [Swift][]
    all feature similar syntax (though with quite different semantics) so
    there's evidence that it's broadly palatable.

*   **It takes advantage of existing language semantics.** The body is just a
    regular block. Aside from the implicitly-declared locals for the named
    arguments and the behavior of `yield`, it reuses Dart behavior that users
    already know.

[ruby]: http://ruby-for-beginners.rubymonstas.org/blocks/arguments.html
[groovy]: http://mrhaki.blogspot.com/2009/09/groovy-goodness-with-method.html
[scala]: https://www.scala-lang.org/old/node/138
[kotlin]: https://kotlinlang.org/docs/reference/type-safe-builders.html
[swift]: https://docs.swift.org/swift-book/LanguageGuide/Closures.html#ID102

#### Cons

*   **It's not clear how to extend this to positional parameters.** Using
    `yield` kind of works for rest parameters, but is verbose. It's not clear if
    it makes sense to extend this to list and (even harder) map literals. Note
    that in the example, I had use an explicit `child = ` since the syntax
    doesn't support non-rest positional parameters.

### Markup

When talking about syntax for building UIs, markup is the elephant in the room.
React has [JSX][]. Scala has [XML literals][]. The idea of embedding an
HTML-like markup syntax in a programming language arouses [very strong feelings
in both directions][dsx].

[jsx]: https://github.com/munificent/ui-as-code/blob/master/JSX.md
[xml literals]: http://tuttlem.github.io/2015/02/24/xml-literals-in-scala.html
[dsx]: https://github.com/flutter/flutter/issues/15922

For Dart, the best idea I've come up with is that a markup tag is syntactic
sugar for invoking a constructor or function. The tag's attributes correspond to
*named* arguments. The body of the tag is a sequence of *positional* arguments.

So this:

```dart
<Container height=56.0>
  <Row>
    <IconButton icon=Icon(Icons.menu) tooltip='Navigation menu' />
    <Expanded child=title />
    <IconButton icon=Icon(Icons.search) tooltip='Search' />
  </Row>
</Container>
```

Is another way of writing:

```dart
Container(
  height: 56.0,
  Row(
    IconButton(icon: Icon(Icons.menu), tooltip: 'Navigation menu'),
    Expanded(child: title),
    IconButton(icon: Icon(Icons.search), tooltip: 'Search')
  ),
)
```

Maybe it's just me, but I think the markup looks pretty nice. However, in more
complex cases, it gets... *strange:*

```dart
<MaterialApp
  home=<Scaffold
    appBar=<AppBar
      title=const Text('AnimatedList')
      actions=[
        <IconButton
          icon=const Icon(Icons.add_circle)
          onPressed=_insert
          tooltip='insert a new item'
        />
        <IconButton
          icon=const Icon(Icons.remove_circle)
          onPressed=_remove
          tooltip='remove the selected item'
        />
      ]
    />
    body=<Padding padding=const EdgeInsets.all(16.0)>
      <AnimatedList
        key=_listKey
        initialItemCount=_list.length
        itemBuilder=_buildItem
      />
    </Padding>
  />
/>;
```

For users that expect "HTML attributes" to be tiny primitive values, it's
unusual to see entire nested trees of tags in there.

Remember, also, that our initial motivation is supporting conditional named
arguments, positional arguments, and list elements. So this entirely new markup
syntax isn't yet sufficient. We also need to extend it to support conditions.

One option is to effectively *also* do the "control flow element" proposal and
allow `if ()` before attributes and child tags. Using that gets us to:

```dart
Widget build(BuildContext context) {
  return <Container
    height=56.0
    padding=const EdgeInsets.symmetric(horizontal: 8.0)
    decoration=BoxDecoration(color: Colors.blue[500])
    child=<Row>
      <IconButton
        icon=Icon(Icons.menu)
        tooltip='Navigation menu'
        if (!isWindows) padding=const EdgeInsets.all(20.0)
      />
      <Expanded>title</Expanded>
      if (!isAndroid)
        <IconButton icon=Icon(Icons.search) tooltip='Search' />
    </Row>
  />;
}
```

#### Pros

*   **Some people really love the way markup looks.** It clearly says
    "declarative data" to them. However, we sacrifice some of this when we
    introduce conditionals and tags inside attributes. We're potentially in the
    uncanny valley where it looks enough like HTML to make them expect it to be
    *exactly* like it, which we then confound.

*   **It eliminates the need for separators or terminators.** Traditional
    argument lists require commas between each element. A block requires
    semicolons after each statement. HTML, interestingly, requires no separators
    at all. So, aside from all the angle brackets, this is less
    punctuation-heavy and perhaps less error-prone than other notations.

*   **Named closing tags make nesting easier to read.** Because Flutter widgets
    tend to nest pretty deeply, the end of a build method is often a [long
    string of `)`, `}`, and `]`][closing]. It can be hard to scan back up and
    see what widget each is associated with. Named closing tags like `</Row>`
    make that clearer.

[closing]: https://github.com/munificent/ui-as-code/blob/master/Motivation.md#p3-long-strings-of-hard-to-read-closing-delimiters

#### Cons

*   **Some people really hate the way markup looks.** You win some, you lose
    some, I guess.

*   **It's verbose.** Brevity doesn't strictly imply readability (as looking at
    a page of APL will make clear), but unnecessary verbosity isn't helpful
    either. Markup is fairly verbose with a lot of angle brackets and named
    closing tags.

*   **It's possibly in the uncanny valley.** We need to deviate from basic HTML
    syntax to support more complex attribute values and conditional evaluation.
    So we run the risk of alienating even users that do like markup syntax.

## Evaluating Contextually

We could weight up those pros and cons and pick an approach. But what I
*haven't* done is evaluate how these features impact the *rest of the language*
and how users actually interact with these features in the context of their
existing program.

Fundamentally, nothing in the "UI as code" charter will let users do something
they can't already do with Dart. It's not like we're adding threads or some
other new capability. All we're doing is making it *easier* to express what they
can already express. That raises the bar for this feature: it must be not just
good but *so much better* that it justifies the additional complexity.

Because of that, I think it's more important to look at the feature in the
context of the entire language than the merits of any feature in isolation,
since users always have the option to *not* use it. Here are a couple of aspects
to evaluate:

### Declarativeness

UI code is easiest to read when the code shows *what* the corresponding UI is,
not *how* it is built up. When looking at declarative-styled code, the structure
of the *program text itself* reflects what it does. With imperative code where
you have a lot of mutation and side effects, you have to simulate the execution
of the code in your head and then visualize the resulting state. That's a much
higher cognitive effort.

Some amount of this is necessary for complex use cases, but as much as possible,
we want most simple UI code to be declarative in nature.

### Switching cost

Imagine you already have a `build()` method containing a big tree of code using
the current Dart syntax. Think [a 30-line expression of nested constructor
calls][chat]. Later, you realize you need to omit one tiny leaf of that tree
based on some runtime condition.

[chat]: https://github.com/munificent/ui-as-code/blob/master/examples/original/chat_message.dart#L27-L61

How much of that code do you have to change or rewrite to make that happen?
Obviously, the less, the better. We can automate the switching with tooling in
some cases, but it still makes things like code reviews harder since the
effective change is buried in meaningless churn.

### Redundancy

Technically, everything in the "UI as code" charter is redundant. You *can* do
everything it enables already. It's just too difficult, error-prone or hard to
read. That means all of these changes foist some level of redundancy onto users
and give them two ways to express the same thing. That raises the cognitive
load of the language itself.

Worse, it forces users to put mental effort into *choosing* which syntax to use,
mental effort that they aren't spending on the real problem they're trying to
solve. [Hick's law][] tells us that the more options a user has, the *longer* it
takes them to pick.

[hick's law]: https://en.wikipedia.org/wiki/Hick%27s_law

To minimize that extra effort, we need guidelines that tell them when to prefer
each syntax. If those guidelines are complex or subtle, they may end up
switching back and forth more frequently, which raises the impact of the
switching cost.

### Heterogeneity

If you have multiple notations for a function invocation or constructor call,
then it's possible to end up with chunks of code that contain a mixture of both
styles. The reader has to mentally switch between the two notations as they read
the whole thing. Different parts of the code that are semantically the same may
look syntactically quite different just because of the notation.

We want to minimize this so that regions of code tend to use one homogenous
style. That implies that the syntax we choose needs to do a great job on a wide
variety of use cases. If, say, blocks are much worse than parenthesized argument
lists for some uses, then users will use the latter even when surrounding code
is using blocks.

That, in turn, tends to raise the amount of redundancy. The new syntax needs to
support lots of use cases, so the total amount of overlapping features goes up.

And, of course, it raises switching costs. When one piece of code needs to use
the new notation, users are encouraged to change the surrounding code too just
to keep things consistent. So the quantity of code being switched tends to grow.

### Garden path syntax

When a language feature is similar to some existing language or model that users
already know, it's easier to learn because they can reuse that existing
expertise. However, when the language feature doesn't *entirely* fit that model,
the familiarity can cause expectations that reality confounds.

I think of these as ["garden path" features][garden]&mdash;the syntax leads them
down a path of only to hit a dead end when it doesn't support everything they
expect.

[garden]: https://en.wikipedia.org/wiki/Garden-path_sentence

For example, Dart allows you to write expressions in places where a constant is
required. Because *some* expressions are allowed, it leads users to believe "I
can put any expression here". But only a very small subset of expressions are
allowed and users are frequently frustrated when they try to step past that
boundary.

To avoid this, we need to be sensitive to the expectations a syntax summons.
When possible, the feature should feel "complete" so that it covers all the
territory they'll expect.

### Future-proofing

Every language proposal claims a chunk of syntax for its own use and ascribes
some semantics to it. That's a region of the grammar that the future Dart
language team won't be able to use for some other potentially more valuable
feature.

For example, you could imagine allowing `?` in a parameter list today to mark a
parameter as optional. That might be nice. But there's a very good chance we'll
add non-nullable types, and our future selves would kick us if we didn't leave
`?` available for use for that.

Worrying too much about this can be paralyzing. We do need to ship features
today, after all. But it's good to be somewhat aware of possible future needs.

## Revisiting the Paths

In light of those aspects, let's go back down the three paths:

### Control flow elements

#### Declarativeness

Expressions are already quite declarative. A list literal like `[1, 2, 3]` just
*is* the list. Contrast that with how you'd imperatively build one manually:

```dart
var list = List();
list.add(1);
list.add(2);
list.add(3);
```

Prefering declarative code then suggests we should prefer expressions. The
control flow element proposal aligns nicely with that&mdash;it moves some of the
control flow you can do in statements already over to the expression side of the
grammar.

Better, the "control flow" it gives you is really closer to "data flow". Then
then and else bodies of the `if` are expressions or elements that implicitly
produce values. You don't have to "yield" or "assign" the result.

#### Switching cost

Excellent shape. This proposal is just an incremental addition to the existing
syntax for argument lists and collections. You don't have to touch any existing
code to take advantage of the feature. In simple cases, it's literally just
adding `if (condition)` before a single argument.

#### Redundancy

Also good. It adds almost no new notation for things you can already do. It
overlaps `?:`, which is pretty hard to read in all but the simplest cases. But
it doesn't add any new redundant notation for invocations, argument lists, or
collections.

#### Heterogeneity

This is also great, thanks to the above. Since there is only one syntax for invocations, it's automatically all homogeneous.

#### Garden path syntax

There are real concerns here, and this is one of the main reasons I hesitate on
this proposal. The feature gives you only two control flow forms (`if` and
`for`), and only allows them in a few select places (argument lists and
collection literals).

Will users want `while` in their list literals? `break`? Will they want to be
able to do:

```dart
var text = if (condition) "yes" else "no";
```

I did choose the limitations deliberately. In order to keep the code
declarative, I think it's good to avoid `break` and supporting arbitrary
statements like local variable declarations or expression statements. If you
find yourself wanting to stuff that all inside an argument list, maybe you
*should* hoist that out.

But this is still something I worry about and will worry about until we do some
user studies or investigation.

#### Future-proofing

This one's not bad. It's a small, incremental addition to the grammar. It only
covers a couple of things, and only applies in a few places. It's not like we're
adding a new expression or statement form.

### Argument initializer blocks

#### Declarativeness

Pretty bad. The body of a block is explicitly imperative&mdash;it's a list of
statements. Statements don't produce values, they just have side effects.
Passing a named argument becomes an assignment. That's not too bad, but
positional arguments are worse.

Requiring an explicit `yield` is imperative and pretty verbose. Compare:

```dart
Row {
  yield Text("1");
  yield Text("2");
  yield Text("3");
}
```

versus:

```dart
Row(
  Text("1"),
  Text("2"),
  Text("3"),
)
```

Or even:

```dart
Row(Text("1"), Text("2"), Text("3"))
```

#### Switching cost

I'm very concerned here too. Imagine you've got some long argument list with a
bunch of arguments. Later, you realize you need to omit just *one* of them
conditionally. With this proposal, you have to turn the parentheses into braces.
Then you have to go through *all* of the arguments and turn commas into
semicolons and colons into equals. Don't forget to add a semicolon after the
last one!

#### Redundancy

Likewise concerning. This introduces an entirely separate notation for an
invocation. For common cases where you *don't* need control flow, this new
notation is a pretty big step down. You can't naturally pack multiple small
arguments on one line like you can with `,`. The `yield` on positional arguments
is verbose.

Honestly, it's pretty hard to beat C function call syntax at its own game.

#### Heterogeneity

Code that contains a mixture of block and normal call syntax looks pretty weird.
You get a mishmash of parentheses, braces, colons, equals, commas, and
semicolons. Nesting normal calls inside blocks is tolerable, but going the other
direction feels strange&mdash;even with lambdas in Dart it always feels odd to
see statements inside expressions.

Worse, because the block syntax is notably worse in common cases, you're more
likely to run into heterogeneous code. Users won't want to use verbose blocks
for things like:

```dart
Text {
  yield "Hi";
}
```

#### Garden path syntax

It scores really well on this axis. The block is a normal Dart block. You have
access to the entire statement grammar in there, so it feels complete. It's one
of my favorite aspects of this proposal.

#### Future-proofing

This does concern me. The fact that several other languages all support similar
notation shows that it's desirable. The fact that they all use it to mean
*something else* hints we may be squandering the syntax on the wrong semantics.

Other languages use it for passing a lambda to a function or for supporting
imperative builder-like DSL APIs. It would be great to have that for Dart. Test
code could look like:

```dart
group("arithmetic") {
  test("addition") {
    expect(1 + 1, equals(2));
  }
}
```

The [built_value builder API][built] could go from:

[built]: https://github.com/google/built_value.dart/blob/master/chat_example/lib/server/server.dart#L30

```dart
Welcome((b) => b
  ..log.addAll(_log)
  ..message = 'You are connected as $username.'));
```

to:

```dart
Welcome {
  log.addAll(_log);
  message = 'You are connected as $username.';
}
```

Flutter's use case is declarative. All it really wants is a notation for calling
a constructor to produce a value. But there are many other DSL use cases that
are explicitly imperative where the API wants to control when and how some code
executes. Those seem like a better fit for a statement-based block syntax.

### Markup

#### Declarativeness

For simple cases, I think this scores well. The syntax is familiar and sends a
strong "this is data" signal to many readers. Child tags for positional argument
looks nice and declarative.

Once you start doing some conditional attributes or child tags, though, it gets
weird. It depends on how we design the conditional execution, but it may throw
off readers when they see an `if` in the middle of what they think of as
"markup".

#### Switching cost

Oh, dear, this one is bad. The notation is radically different from the current
invocation syntax. You need angle brackets. Closing tags (including the name,
which gets very strange if the thing you are calling is a generic constructor).
You may need to escape or parenthesize subexpressions. Removing the commas and
turning `:` into `=` is the "easy" part.

The hard part is that you need to *reorder* the arguments&mdash;named ones need
to go first as attributes and positional ones later as child tags. That's the
exact opposite order from what Dart requires in invocations. Reordering these
arguments can potentially interfere with evaluation order in ways that matter.

#### Redundancy

This is also bad. Like the block proposal, it's an entirely new separate syntax
for an invocation. In addition to defining this new tag syntax we also still
need to define an *additional* notation on top of it for condition arguments.
Because attributes (named args) and child tags (positional args) are so
syntactically different, we also basically need to define the conditional syntax
twice.

#### Heterogeneity

Assuming you like markup syntax, this is so-so. It's pretty declarative, so it
works OK even in simple cases that don't need conditionals. It is more verbose,
so tiny cases look weird. Users may not want to write:

```dart
<Text>"some string"</Text>
```

When they can just do:

```dart
Text("some string")
```

Using tag syntax in attributes looks pretty strange:

```dart
<IconButton
  icon=<Icon>Icons.menu</Icon>
  tooltip='Navigation menu'
  padding=<const EdgeInsets.all>20.0</EdgeInsets.all>
/>
```

That might encourage users to use the classic syntax in attribute position for
some cases and tags for others, which would increase the heterogeneity.

#### Garden path syntax

This is also so-so. The subset of XML and HTML most people know is pretty small
and the proposed syntax here covers most of it, so it feels fairly complete.

We do have to decide what's allowed in the body of a tag where the children
appear. If it's a full block where you can have arbitrary statements, then it's
less of a garden path, but you have to figure out how positional arguments work.
If it's just a list of positional arguments with some special support for `if
()`, then that may feel like a limitation.

#### Future-proofing

This is fine. It carves out an entirely new region of the grammar. Unlike JSX,
EX4 and Scala XML literals, the proposed syntax here desugars to calling
arbitrary user-defined APIs so that gives the syntax a lot of freedom to evolve
for different use cases in the future.

## Conclusion

I don't think you can always do good holistic design by tallying numbers, but
just to visually see all of the above prose in one place:

```
                    control elements    block    markup
prefer declarative  :D                  :(       :/
switching cost      :D :D               :( :(    :( :(
redundancy          :D :D               :( :(    :(
heterogeneity       :D :D :D            :(       :/
garden path         :(                  :D :D    :/
future-proofing     :/                  :(       :D

totals:
control elements    :D :D :D :D :D :D :D :D   :(
block               :D :D                     :( :( :( :( :( :( :(
markup              :D                        :( :( :(
```

Note that this ignores the pros and cons of the features themselves. If you
think, say, the markup syntax is *great* on its own, that may outweigh its poor
interaction with the rest of the language and Dart user experience.

But my belief is that, especially for syntactic sugar features, those
interactions do dominate. And, looking at the totals, there's a pretty clear
winner. This, honestly, quite surprised me. For months, I have been personally
strongly attached to the block and markup syntaxes. (Like children, on any given
day, either may be my favorite.)

As cool as both of those notations are, I think the reality is that it would be
a constant hassle to use them in existing code. The result would be a
Frankenstein assemblage of different syntaxes and a lot of churn between the two
styles.

Control flow elements is a small, limited feature. But I also feel that it's
"right-sized" for the problem it intends to tackle. Its small size helps it
harmonize with existing code and lets the current invocation syntax continue to
do what it does well. It's useful for code well outside Flutter. Here's an example I stumbled onto:

```dart
// compile.dart
var command = [
  engineDartPath,
  frontendServer,
  '--sdk-root',
  sdkRoot,
  '--strong',
  '--target=flutter',
];
if (trackWidgetCreation)
  command.add('--track-widget-creation');
if (!linkPlatformKernelIn)
  command.add('--no-link-platform');
if (aot) {
  command.add('--aot');
  command.add('--tfa');
}
if (targetProductVm) {
  command.add('-Ddart.vm.product=true');
}
if (entryPointsJsonFiles != null) {
  for (var entryPointsJson in entryPointsJsonFiles) {
    command.addAll(['--entry-points', entryPointsJson]);
  }
}
if (incrementalCompilerByteStorePath != null) {
  command.add('--incremental');
}
if (packagesPath != null) {
  command.addAll(['--packages', packagesPath]);
}
if (outputFilePath != null) {
  command.addAll(['--output-dill', outputFilePath]);
}
if (depFilePath != null &&
    (fileSystemRoots == null || fileSystemRoots.isEmpty)) {
  command.addAll(['--depfile', depFilePath]);
}
if (fileSystemRoots != null) {
  for (var root in fileSystemRoots) {
    command.addAll(['--filesystem-root', root]);
  }
}
if (fileSystemScheme != null) {
  command.addAll(['--filesystem-scheme', fileSystemScheme]);
}

if (extraFrontEndOptions != null)
  command.addAll(extraFrontEndOptions);
command.add(mainPath);
```

With control flow elements, all of that fits into the list literal:

```dart
// compile.dart
var command = [
  engineDartPath,
  frontendServer,
  '--sdk-root',
  sdkRoot,
  '--strong',
  '--target=flutter',
  if (trackWidgetCreation) '--track-widget-creation',
  if (!linkPlatformKernelIn) '--no-link-platform',
  if (aot) ('--aot', '--tfa'),
  if (targetProductVm) '-Ddart.vm.product=true',
  if (entryPointsJsonFiles != null)
    for (var entryPointsJson in entryPointsJsonFiles)
      ('--entry-points', entryPointsJson),
  if (incrementalCompilerByteStorePath != null) '--incremental',
  if (packagesPath != null) ('--packages', packagesPath),
  if (outputFilePath != null) ('--output-dill', outputFilePath),
  if (depFilePath != null &&
      (fileSystemRoots == null || fileSystemRoots.isEmpty))
    ('--depfile', depFilePath),
  if (fileSystemRoots != null)
    for (var root in fileSystemRoots)
      ('--filesystem-root', root),
  if (fileSystemScheme != null) ('--filesystem-scheme', fileSystemScheme),
  if (extraFrontEndOptions != null) ...extraFrontEndOptions,
  mainPath
];
```

Notice how all of the imperative `command.add(...)` and `command.addAll(...)`
calls are gone. The fact that this makes such a big difference in a chunk of
code so far removed from UI helps me believe the feature will be broadly useful.

Control flow elements may end up falling apart as I dig into the details of a
full proposal, but I have more confidence in it than I do the other paths that
have known challenges. I think it's the path we should try to go down first, and
I think it's the most promising path to eventual success.
