# Goals

The main measure of this feature's fitness is how well it solves our [user
problems][problems]. Those are the primary requirements. Still, it's possible to
design a feature that checks those boxes but isn't a good feature.

[problems]: https://github.com/munificent/ui-as-code/blob/master/Motivation.md

This doc defines a set of goals to constraint what good feature looks like in
the larger context of the language and ecosystem. These aren't hard
requirements, more like trade-offs. We won't maximize all of these, but we
should know when we aren't and why.

In roughly descending order:

## It must be amenable to static typing

This goes without saying, but it does constrain the design space so it's worth
spelling out. Users should not have to sacrifice static safety to use the new
syntax.

## We must be able to ship it

There may be a beautiful syntax out there that would take us ten years to
research and design. Or perhaps it would require a long series of breaking
changes and migrating millions of lines of code. Maybe it would require writing
an entirely new front end. Or maybe it would just be so avant garde that we
couldn't convince users to adopt it.

Users have problems *today* and our job as engineers is to implement solutions
in the real world under real resource constraints. A good feature is one we can
build and ship in a reasonable amount of time, one we can write clean tests and
docs for, and one users can learn and use in their existing Dart code the day we
launch it.

## It should help more libraries than just Flutter

Out of the box, React's [JSX][] notation literally compiles to calls to
`React.createElement()`. That's not a useful syntax unless your framework also
happens to be named "React". (You can customize the name of the function it
compiles to using a special `/** @jsx ... */` comment, but that's a little off
the beaten path.)

[jsx]: https://reactjs.org/docs/introducing-jsx.html

Flutter is fantastic, but other frameworks and libraries are fantastic too. If
we're going to take the trouble to add new real syntax into the Dart grammar, we
should get as much value out of it as we can by making it usable for a variety
of APIs.

A good example of this is Dart's `for-in` statement. The language gives you the
syntax, and the semantics are defined in terms of the `Iterable` protocol. This
lets any Dart class implement that protocol and plug itself into that corner of
the grammar.

## It should support more use cases than just UI

The motivating use code for this work is constructing trees of Flutter widget
objects. That easily generalizes to any other React-style UI framework, but we
should look farther afield than that. Ideally, the syntax we design is useful
for any API where you have large nested expressions.

Consider questions like:

*   Does the syntax always need to *construct objects*, or can it perform other
    operations?

*   Can it work well for argument lists that are large but not necessarily
    deeply nested? Conversely, is it helpful for deeply nested but otherwise
    small invocations?

*   Could you use the syntax for creating mock protobuf objects in tests?
    Defining the kinds of treasure for a game? Build a grammar using a parser
    combinator library? Author a BDD-style test?

The syntax doesn't need to be all things to all people. Solving a larger set of
problems often involves compromising how well it solves any one of them. It's
better to do a handful of things really well than a whole bunch of things kind
of OK.

But to the degree that we can widen the scope of the syntax without watering it
down, we should. We can't predict everything our users will do with Dart in the
future, so we should give them as much room to grow as we can.

## It shouldn't give users ambiguous choices

Since Dart first launched, users have told us one of the things they like about
the system is that it's *opinionated*. There is one idiomatic, blessed way to do
*X* for most values of *X*. They like that we have a single, full-featured core
library instead of needing to choose from a slew of overlapping utility
packages. They like that Futures and Streams are the blessed way of doing
asynchrony. They like having a canonical style in dartfmt.

Fundamentally, this new syntax goes against that. Since it exposes no actual new
*capabilities*, it is literally a second way to do the same thing. This is OK as
long it's clear *which* of those two ways they should use in any given
situation.

A good solution makes it clear which kind of code it's best suited for and which
code it's not. When it's not obvious and we have to choose, it should be easy to
write clear, simple guidance in "Effective Dart" or elsewhere for which syntax
to use. If possible, the guidance should be so simple that it can be
mechanically detected by linters.

## It should minimize semantic redundancy

A typical solution for defining UI in code is adding some kind of markup
notation into the language. [JSX][], [E4X][], and XML literals in Scala are
examples. (PHP is an interesting example of going the *other*
direction&mdash;introducing an imperative language into a markup language).

[e4x]: https://en.wikipedia.org/wiki/ECMAScript_for_XML

If that markup notation is totally distinct from the regular language, the
tendency is to then re-invent new ways to express things the other language
already handles perfectly well. For example, JSX has no built-in control flow,
so some users define [libraries to re-implement
it](https://github.com/AlexGilleran/jsx-control-statements):

```
<If condition={ true }>
  <span>IfBlock</span>
</If>
```

There will obviously be *some* redundancy (see the previous guideline), but we
should avoid defining two large, disjoint languages that each have their own way
to express the same things. Doing that makes it harder for users to mentally
switch between the two when reading code, and makes it hard to move code from
one notation to the other.

This is potentially a problem even in non-markup-like approaches. Any time we
add a large chunk of new grammar that's distinct from existing syntax but has
overlapping semantics, we are increasing the cognitive load of the language.

## It should minimize syntactic overloading

A challenge with introducing new expression syntax into Dart is that the grammar
is already quite full. There are only so many ASCII characters and many of them
were claimed by Ritchie ages ago. (The temptation to incorporate emoji is real,
but best avoided.)

To pack in new semantics, languages end up reusing characters to mean something
different in a different context. Curly braces can mean a block statement, class
body, function body, or map literal. Square brackets can be subscripting or a
list literal. Angle brackets are comparisons or type parameters. A dot can be a
decimal point, prefix separator, instance member access, or static member
access. (In all of these cases, note that there is an older C-era usage and
newer ones added later.)

When existing punctuation or keywords are repurposed to mean something new,
there is less visual signal for readers skimming code to clue into the right
mental mode. It's easy to misread something and not realize what it does.

If we go with a non-markup syntax, this is more likely to be a challenge because
we'll be stuffing new syntax inside Dart's already-full expression grammar.

This doesn't mean a new syntax must directly summon one concrete behavior. For
when you see a `for-in` loop, the syntax doesn't tell you *what* you are
iterating over or *how*, it just tells you some kind of iteration is going on.

This goal and the previous one mean we should aspire to make the same semantics
look the same and make different semantics look different. A non-markup approach
generally makes the former easier because it's easier to reuse existing
expression forms. A markup-like syntax makes the latter easier because it carves
out its own less-populated region of grammar.

The best solution may be a blend of both.

## It should harmonize with Dart's syntactic history

Dart is a conservative language in the C/Java/JS tradition. Statements, curly
braces, `.foo()` for method calls, etc. This makes it easy for users coming from
those or other similar languages to get up and running in Dart quickly.

Any new syntax should meld with that as much as possible. Instead of designing a
new syntax from a blank slate and first principles, it should take advantage of
Dart's history and the syntax and semantics already loaded into our users'
heads.

A good example is the `=>` syntax for defining members. It was a novel feature
at the time. Other languages used `=>` or `->` for defining *lambdas*, which
gave it familiarity. Then Dart extended that in a natural way to member
declarations too.

If we do our job right, most people who like Dart's current syntax will not
recoil in horror at the new notation. They will be able to somewhat intuit what
it does without being directly taught based on how the notation compares to
syntax they already know.

## It should be relatively easy to parse

This goal isn't literally about how difficult it is to implement a parser for
the new syntax. Dart already has arbitrary lookahead for function literals,
contextual keywords, and other tricky edge cases. It's good to not pile more
complexity on top of that, but we'll never be Lisp.

The goal is more that it should be easy for *humans* to parse. In many cases,
parser implementation complexity correlates to that, so a simple grammar is a
sign that we've got something easy for people to read too.

Also, an easy syntax to parse makes it easier for people to maintain text
editors, syntax highlighters, linters, and other tools that work with Dart
source code but aren't as sophisticated as a complete front end.

But if we have to choose between syntax A which tests well in usability studies
but requires some extra lookahead and syntax B which is grammatically simpler
but more error-prone, then we'd probably pick A.
