# Parameter Freedom

Loosen restrictions around positional, optional, and named parameters. Then add
rest parameters (and a spread operator) so that API authors can define flexible
expressive parameter lists that free callers from writing useless boilerplate.

## Motivation

For the "UI as code" work, my goal is a holistic package of language changes
that hang together and harmoniously improve the user experience of the code.
But, in order to make progress, it's useful to break that package out into
individual proposals that we can work on independently and incrementally.

Every set of features I've considered so inevitably seems to include at least
three changes to parameter lists:

### Allow passing positional arguments after named arguments

Named parameters are great when they are all optional and any combination of
them is valid (1). Positional parameters are great when the argument is
mandatory or the name is obvious from the method being called (2). Finally, code
tends to be easiest to read when the largest argument expression is last (3).

In particular, if a method takes a big function literal, collection, or other
large nested expression as an argument, you really want it to hang off the end.
Unfortunately, these three constraints often conflict:

```dart
DefaultTextStyle(
  style: Theme.of(context).text.body1.copyWith(fontSize: config.fontSize),
  child: Column(
    children: [
      Flexible(
        child: Block(
          padding: const EdgeDims.symmetric(horizontal: 8.0),
          scrollAnchor: ViewportAnchor.end,
          children: messages.map((m) => ChatMessage(m)).toList(),
        ),
      ),
      _buildTextComposer(),
    ],
  ),
),
```

Here, you want the `child` widget to be the last argument because it's much
larger that the smaller `style` argument. But it should also be mandatory and
arguably the `child` name doesn't add much value here.

The problem is a simple syntactic limitation: Dart doesn't let you place
positional arguments following named ones. Removing that restriction would let
you turn `child` into a mandatory positional parameter and write:

```dart
DefaultTextStyle(
  style: Theme.of(context).text.body1.copyWith(fontSize: config.fontSize),
  Column(
    children: [
      Flexible(
        child: Block(
          padding: const EdgeDims.symmetric(horizontal: 8.0),
          scrollAnchor: ViewportAnchor.end,
          children: messages.map((m) => ChatMessage(m)).toList(),
        ),
      ),
      _buildTextComposer(),
    ],
  ),
),
```

### Allow both optional positional and optional named parameters

At the point that optional parameters were first designed, we knew this was an
arbitrary limitation. Today, DDC's current ABI may make it a challenge to
support both, but it's likely we can fix this.

The current restriction this causes a couple of problems:

*   **If you want to give a name to one optional parameter, you have to name
    *all* of them.** This can lead to not-very-useful parameter names like
    `child` and `children`. Because methods taking those have parameters that
    should be named, and because these parameters are optional too, they have to
    be named as well, even though the name communicates little.

*   **Once a method chooses an optional style, it is stuck with it.** You define
    a method that takes an optional positional parameter and ship the API.
    Later, you want to add another optional parameter. That's a non-breaking
    change. But that parameter really *should* be named. Alas, you can't do
    that. You have to go back and change the existing parameter to be named too,
    which is a breaking change.

    The language team has a goal to improve the ability to evolve APIs without
    breaking them. This is one of the corners of the language that causes that
    unneeded breakage. Allowing a single method to take both optional positional
    *and* optional named fixes that.

    (See [issue #21406][].)

Assuming we can solve the ABI problems in DDC, supporting this is as close to a
pure win as anything in languages ever is.

(See [issue #7056][].)

### Support rest parameters

Almost every language has a way to pass a unbound series of arguments of the
same type to a method without having to explicitly create a list or
array&mdash;usually called "varargs", "variadic parameters" or "rest
parameters". Dart doesn't, which leads to a large amount of boilerplate
`children: [ ... ]` code in Flutter widgets. This is something Flutter users
often complain about.

Because Dart doesn't support this and JavaScript does, we have to [work around
it in interop][js rest].

Having real support for rest params also potentially unlocks some performance
improvements since the compiler can usually tell that the synthesized list is
not mutated elsewhere.

(See [issue #16253][], StackOverflow [1][so 1], StackOverflow [2][so 2].)

### Non-trailing optional parameters

Dart currently requires all optional positional parameters to be at the end of
the parameter list. In most APIs, it's fine to force all the optional parameters
to the end of the argument list. However, sometimes this leads to an unnatural
parameter order. This is exacerbated by the lack of overloading in Dart.

A classic example is a function that returns a random integer in a given range.
You can give it one argument to return a number between 0 and that maximum. Or
you can pass two arguments, a min and max. In Dart, that looks like:

```dart
int random(int minOrMax, [int max]) {
  // ...
}
```

That weird first parameter name is because what it represents depends on whether
or not the second parameter is passed. The problem is much worse if the two
parameters need to have different types. At that point, you are usually forced
to make both named and throw an exception if the user passes the wrong one.

Individually, these are all fairly minor changes. But given how much
code&mdash;especially Flutter UI code is composed of method invocation, these
changes can have a large impact on the clarity and brevity of a user's program.
They probably won't move the needle&mdash;we should look into more ambitious
features in addition to these&mdash;but they eliminate a large number of small
frictions.

Since these changes are intertwined in the same corner of the language's
semantics and grammar, this proposal addresses them all together.

## Proposal

The rest of the proposal goes into detail about each change, but here is a quick
introduction to the proposed solutions to the above problems. Two of the
"solutions" are obvious. For these:

* Allow passing positional arguments after named arguments.
* Allow both optional positional and optional named parameters.

We simply remove the language restrictions that prohibit doing that. There are
some interesting technical questions about how that affects calling conventions,
but the syntax and semantics are obvious.

### Non-trailing optional parameters

Non-trailing optional parameters is a little more complex. To enable that, we
let a function contain multiple `[...]` sections, with non-optional parameters
between them:

```dart
method(int a, [bool b, double c], num d, [String e]) { ... }
```

That, of course, is a pathological example. Almost all real code will contain a
single optional parameter section, usually just a single parameter. A typical
idiomatic use is more like:

```dart
int random([int min = 0], int max) {
  // ...
}
```

When calling a method where the optional parameters aren't necessarily at the
end, we rely on the arity of the call to determine which parameters are bound
and which aren't. Once you determine which parameters will get bound and which
won't, arguments are bound to parameters from left to right.

With the above, the valid calls are:

```dart
random(10); // Uses the default for min and binds 10 to max.
random(5, 15); // Binds 5 to min and 15 to max.
```

This might seem tricky in complex cases, but it works out OK. We go into full
details later. The mechanism is the same as what Ruby 1.9 and other languages
use.

### Support rest parameters

To support rest parameters, we add one more allowed section to a parameter list.
A rest parameter is an (optional) type followed by `...` and then a parameter
name. For example:

```dart
runProcess(String command, List<String> ...arguments) { ... }

main() {
  runProcess("cat", "file1.txt", "file2.txt");
}
```

If you want to expand a collection object into a sequence of rest parameters,
you can use the "spread" operator:

```
var files = ["file1.txt", "file2.txt"];
runProcess("cat", ...files);
```

With all of these changes, some Flutter code that looks like this:

```dart
DefaultTextStyle(
  style: Theme.of(context).text.body1.copyWith(fontSize: config.fontSize),
  child: Column(
    children: [
      Flexible(
        child: Block(
          padding: const EdgeDims.symmetric(horizontal: 8.0),
          scrollAnchor: ViewportAnchor.end,
          children: messages.map((m) => ChatMessage(m)).toList(),
        ),
      ),
      _buildTextComposer(),
    ],
  ),
)
```

Can become:

```dart
DefaultTextStyle(
  style: Theme.of(context).text.body1.copyWith(fontSize: config.fontSize),
  Column(
    Flexible(
      Block(
        padding: const EdgeDims.symmetric(horizontal: 8.0),
        scrollAnchor: ViewportAnchor.end,
        ...messages.map((m) => ChatMessage(m)),
      ),
    ),
    _buildTextComposer(),
  ),
)
```

It's not a radical difference, but it's hopefully a real improvement. The above
is pretty hand-wavey so let's see if we can find any devils in the details.

## Syntax

I've never been thrilled about Dart's parameter syntax. The square brackets and
curlies are pretty weird and unintuitive. But they're what we have and it's hard
to come up with something better that covers all of the various use cases.

If/when we later add support non-nullable types, I think we should revisit
parameters and consider using the nullability of a parameter to imply
optionality too. In the meantime, this proposal takes a conservative approach.

### Support rest parameters

Coming up with a syntax for rest parameters is a little challenging. Some
languages use a keyword (`params` in C#, `vararg` in Kotlin), some use a `*`
(prefix in Ruby and Python, postfix in Scala), and some use `...` (postfix in
Java, prefix in JavaScript).

Since Dart's syntactic legacy most strongly follows JavaScript and Java, I
prefer `...`. I think it's more familiar and also stands out. If we later add
support for destructuring assignment, that's the syntax we'd likely want to use
for rest arguments there.

Figuring out *where* to place it is a little harder. Scala and Java
place the modifier on the type:

```java
void concat(String... arguments) { ... }
```

```scala
concat(arguments : String*) = ...
```

This also implicitly changes the type of the corresponding collection.
`String...` declares an *array of strings*, not a string. Since putting `async`
on a function does *not* implicitly wrap the return type in `Future<...>`, that
didn't feel right to me for Dart (even though I like the brevity). Instead, I
put it before the parameter name:

```dart
void concat(List<String> ...arguments) { ... }
```

Technically, that *is* the same as the Java syntax, except for the space. That's
probably good for familiarity. But note that you are responsible for choosing an
appropriate collection type.

There is a valid argument that `*` is a better choice for Dart given `sync*` and
`yield*`. A user study would help us choose between the two. I could go either
way. If we switch to `*` for rest, we should do the same for spread.

### Argument invocation

There are two changes to the calling side of the grammar:

* Allow positional arguments after named ones.
* Allow spread arguments.

Note that spread is *not* a general expression form. It's only allowed in an
argument list. There isn't a lot of difficulty here, so let's go straight to the
grammar:

```
arguments:
  '(' argumentList? ')'
  ;

argumentList:
  argument (',' argument)* ','?
  ;

argument:
  label? expression |
  '...' expression
  ;
```

Note that there is no "named spread" syntax. Rest parameters, by their nature,
are never named.

### Parameter list grammar

We have three changes to parameter lists:

* Allow both optional positional and optional named parameters
* Support rest parameters
* Non-trailing optional parameters

I think the following grammar changes cover them:

```
formalParameterList:
  '(' ')' |
  '(' positionalSections ')' |
  '(' namedParameters ')' |
  '(' positionalSections ',' namedParameters ')' |
  ;

positionalSections:
  positionalSection ( ', ' positionalSection )*
  ;

positionalSection:
  normalFormalParameter |
  restParameter |
  '[' defaultFormalParameter (', ' defaultFormalParameter)* ']'
  ;

restParameter:
  finalConstVarOrType? '...' identifier
  ;
```

*(Remark: Why is it always so awkward to specify optional things separated by
commas in BNF?)*

It is a compile-time error if a parameter list contains multiple rest
parameters. It is a compile-time error if a parameteer list contains multiple
adjacent optional parameter sections. (The latter isn't harmful, but we prohibit
it to avoid two ways of expressing the same thing.)

## Semantics

You can think of a function type as specifying a signature for how you can call
it and a type that you get in return. We'll ignore return types since they
aren't relevant to this proposal. So:

```dart
function(int a, bool b, String c)
```

Lets you call it like:

```dart
function(1, true, "three")
```

When a function type has optional parameter, you can think of it as specifying a
*set* of "overloaded" signatures, all of which are valid. So:

```dart
function(int a, [bool b, String c])
```

Is conceptually a bundle of three overloads:

```dart
function(int a)
function(int a, bool b)
function(int a, bool b, String c)
```

Named parameters work in a similar way except you get the combinatorial
explosion of overloads:

```dart
function(int a, {bool b, String c})
```

Is conceptually a bundle of three overloads:

```dart
function(int a)
function(int a, bool b:)
function(int a, String c:)
function(int a, bool b:, String c:)
```

(I'm using fake `:` syntax here to indicate parameters that must be passed by
name.)

The rule for binding arguments to parameters is that as long as the argument
list matches one of the function's overloads, it's a valid call to that
function.

For subtyping, the rule is a function must have at least all of the overloads of
the supertype to be a subtype. So given:

```dart
function(int a, [bool b, String c])

// Which expands to:
function(int a)
function(int a, bool b)
function(int a, bool b, String c)
```

This is a valid subtype (and thus overriding method):

```dart
sub(int a, [bool b, String c, double d])

// Which expands to:
sub(int a)
sub(int a, bool b)
sub(int a, bool b, String c)
sub(int a, bool b, String c, double d)
```

It adds *another* overload, but that's OK. (This is also why adding an
*optional* parameter to a superclass method is a breaking change. It adds a new
overload that the subclass overrides may not all support.)

This "overload" model will help us reason through the changes in this proposal.

### Supporting both optional positional and optional named parameters

From the language's perspective, this one is easy. The static and dynamic
semantics around positional and named parameters in Dart are disjoint.
(This is unlike most languages where you can pass any parameter by name or
position.) To support both, we just do both in a single function.

From an implementation perspective, there are possibly some challenges. I
believe DDC's function calling convention (and thus its JS interop API) takes
advantage of the fact that a function cannot have both optional positional and
named parameters, and that the optional positional parameters are all at the
end.

Other implementations may have other challenges fitting both kinds of optional
arguments into their calling convention. We'll have to work with those teams to
see how much of an issue this is.

### Interleaving required and optional positional parameters

Dart's current restrictions around optional parameters simplify what it means to
"choose an overload" when resolving and type checking a call and when doing
subtype tests between functions. Since the optional arguments are always at the
end, and filled in left-to-right, the presence or absence of an optional
argument never "shifts" any other arguments.

This means that if, say, the second parameter has type String, that is true
across all overloads. This lets you type check calls and subtypes by just
walking the parameter list and ignoring overloads and optional parameters.

If we allow interleaving optional parameters and required ones, we lose that
property:

```dart
function([int a], String b)

// Which expands to:
function(String b)
function(int a, String b)
```

The type of the first parameter depends on which overload is chosen. However,
this is not a fatal flaw. The operations we need to perform on function types (details below) are more complex but still tractable.

We do have to figure out how to handle cases where optional arguments are interleaved and not all are provided. Consider:

```dart
function([int a], int b, [int c], int d, [int e], int f)
```

If you call it like:

```dart
function(1, 2, 3, 4)
```

Which parameters get bound to arguments and which use their defaults? We can
actually continue to use the same rule Dart has today: optional parameters are
given priority from left-to-right. So, if there aren't enough arguments to go
around, an optional parameter on the left will get one before a parameter on the
right does.

This does *not* mean that arguments are bound in priority order. We use priority
to determine, statically, *which* parameters will get argument. Once that's
done, arguments are bound to parameters strictly from left-to-right as they are
today.

So, in the above example, the parameters are bound to:

```
a: 1, b: 2, c: null, d: 3, e: null, f: 4
```

I realize that's somewhat confusing, but this is a *very* pathological example.
In simple cases, I think the behavior does about what you expect. The important
parts are:

*   We can determine which "overload" is chosen, and thus the types of each
    parameter by looking at just the arity of the invocation, which is
    statically known.
*   We don't need to use the types of any parameters to determine how optional
    parameters are bound.
*   Existing Dart functions continue to behave the same as they do today.

### Rest parameters

It seems like rest parameters would throw the above model out the window. They
introduce an effectively infinite number of "overloads" to a function. However,
once you get past a single rest argument, every overload beyond that has the
same structure&mdash;you just insert more of the same argument type at a certain
position.

What about mixing rest parameters and optional positional parameters in the same
function? For example:

```dart
function(int a, [int b], List<int> ...c, int d, [int e])
```

(Granted, again, no one would write reasonable code like this. But if the
proposal can handle it, it can handle the code people *do* write without
breaking a sweat.)

We use a similar principle to the previous section. Now we have three levels of
priority when deciding which parameters will capture arguments:

1. Required parameters take highest priority.
2. If there are still arguments left, optional parameters take priority, in
   order from left to right.
3. If there are still arguments left, then the rest parameter takes the rest
   (hence the name).

Again, prioritization is about determine *which* parameters will have arguments.
Once that's determined, arguments are assigned strictly left to right. Here's
how a few calls to the above function get bound:

```dart
function(1, 2) // a: 1, b: null, c: [], d: 2, e: null
function(1, 2, 3) // a: 1, b: 2, c: [], d: 3, e: null
function(1, 2, 3, 4) // a: 1, b: 2, c: [], d: 3, e: 4
function(1, 2, 3, 4, 5) // a: 1, b: 2, c: [3], d: 4, e: 5
function(1, 2, 3, 4, 5, 6) // a: 1, b: 2, c: [3, 4], d: 5, e: 6
```

This lets us decide which positional arguments get shunted into the rest
parameter. The implementation then takes those arguments and bundles them into a
*rest parameter object*. (An optimized implementation may not actually
materialize the object, but from the user's perspective, it conceptually
exists).

Since the implementation creates the object, there are some restrictions on what
types are allowed for a rest parameter. It is a compile-time error for a rest
parameter to have a static type other than `dynamic` or `List<T>` for some `T`.
(We allow `dynamic` mostly to support unannotated rest parameters.)

Once the implementation has created the rest parameter object, how does it
behave? The goal is to give users a useful object while also giving
implementation teams as much room to optimize as possible.

To that end, inside the body of the function, the object:

*   Implements `List<T>`. If the static type of the rest parameter is `List<T>`
    for some `T`, then the rest parameter object's type has that same type
    parameter. Otherwise, it's `List<Object>`.

*   *May* throw a runtime exception on any attempts to modify the object. This
    lets implementations reuse a const empty list in cases where no arguments
    are passed or otherwise use an optimized representation that doesn't
    support mutability.

*   If all of the rest arguments come from a single spread argument, the rest
    parameter object *may* be the original object was spread. In other words:

    ```dart
    var restObj;
    function(List ...rest) {
      restObj = rest;
    }

    var list = [1, 2, 3];
    function(...restObj);
    print(identical(list, restObj));
    ```

    It is implementation-defined when this choose to print "true" or "false".
    Basically, if you are taking a rest parameter, assume you can read from it
    inside the body of the function but otherwise treat it as ephemeral.

### Spread arguments

In order to ensure that we can statically analyze calls based on arity, we need
to take some care when using the spread operator. Unlike dynamically-typed
JavaScript, we can't (easily) support things like:

```dart
function(int a, int b, [int c]) { ... }

var args = [1, 2, 3];
function(...args);
```

Because you could get into weird situations like:

```dart
function(int a, int b, [String c]) { ... }

var args = [1, 2];
if (flipCoin()) args.add(3);
function(...args, "a string");
```

How do you type check that? To avoid this situation, spread arguments are *only*
allowed in a position where it will be bound to a rest parameter. You cannot
spread to other parameters. You *can* have multiple spreads, even spreads
interleaved with other non-spread arguments. They just all need to get bound to
the rest parameter, as in:

```dart
function(String a, List<int> ...ints, double b) { ... }

var args = [2, 3];
var more = [5, 6];
function("string", 1, ...args, 4, ...more, 1.2);
```

### Binding arguments to parameters

The above is a still pretty hand-wavey, so here's a more precise description of
how a given list of positional arguments are bound to a function's required,
optional, and rest parameters. (Named arguments work as normally and are not described here.)

It happens in two phases. First is a static resolution process. It determines if
a list of arguments is valid for the signature of the method being invoked, and
which arguments are bound to which parameters. It only needs access to
information known statically from the method signature and the callsite:

*   The parameter list of the method. For each parameter, its name and whether
    it is optional, a rest parameter, or neither.
*   `argCount`, the number of positional arguments.
*   The static types of each argument and parameter, for type-checking.

1.  **Bind arguments.**

    2.  Let `required` be the number of required positional parameters.

    3.  Let `optional` be the number of optional positional parameters.

    4.  If `required > argCount`, then there are not enough arguments for all
        the required parameters. Compile-time error.

    5.  If there is not a rest parameter and `argCount > required + optional`,
        then there are too many arguments. Compile-time error.

    6.  Let `restArgs` be `argCount - required - optional`. (It may be less than
        zero. That's OK.)

    7.  At this point, we know the invocation is valid. Now we can assign
        argument positions to parameters. Start with the first positional
        argument. For each positional parameter:

        1.  If the parameter is required or is optional and we have not run out
            of arguments yet:

            1.   If the current argument is a rest argument, compile-time error.

            2.   Otherwise, bind the current argument to the parameter and
                 advance to the next argument.

        2.  If the parameter is the rest parameter:

            1.  If `restArgs` is greater than zero, then bind that many
                arguments to the rest parameter and advance past them. If any of
                them are spread arguments, note that they need to be unpacked.

            2.  Otherwise, the rest parameter gets no arguments and will be an
                empty list.

        3.  Otherwise, the parameter is not bound to an argument.

3.  **Type check.** Now that we have bound each argument to a parameter, type
    check them as usual.

This either produces a compile-time error in which case the call is invalid, or
it produces a binding that maps argument positions to parameters.

At runtime, there isn't much left to do:

1.  For each parameter:

    1.  If an argument position is bound to the parameter, use that value.

    2.  Otherwise, use the parameter's default value.

Another way to say all this is that the compiler should be able to desugar the
call to a straight series of positional arguments and an explicitly reified
collection for the rest parameter.

### Function subtyping

A function type contains a (possibly empty) ordered list of *positional
parameters*. Each positional parameter has a type and may be optional or
required. One required parameter may be a *rest* parameter. A function type also
contains a (possibly empty) set of *named parameters*. Each named parameter has
a *name* (obviously) and a type.

I'm ignoring generic type arguments because they aren't affected by this
proposal. To determine if function type `Type` is a subtype of function type
`Supe`:

1.  Let `required` be the number of required positional parameters in `Supe`.

    Let `positional` be the total number positional parameters in `Supe` &mdash;
    required, optional, and rest.

    It is valid to call `Supe` with anywhere from `required` to `positional`
    positional arguments (or more if there is a rest parameter, but we can
    ignore more than one of those).

    For each arity `arity` in that range:

    1.  Get the parameter list used for `Supe` at arity `arity` (see below).

    2.  Get the parameter list used for `Type` at arity `arity`. If it does not
        have a valid one, `Type` is not a subtype.

    3.  Otherwise, for each corresponding pair of parameters `pType` and `pSupe`
        in the parameter lists:

        1.  If `pSupe` is not a subtype of `pType`, `Type` is not a subtype.
            This is the usual contravariant parameter subtype rule.

        2.  If `pType` is a rest parameter and `pSupe` is not, or vice versa,
            `Type` is not a subtype.

2.  It the return type of `Type` is not a subtype of the return type of `Supe`,
    `Type` is not a subtype.

3.  Apply the existing function subtyping rules for named parameters.

4.  If we get here, `Type` is a subtype.

#### Parameter list at arity

To generate the parameter list of a function type `Type` at arity `arity`:

1.  Let `positional` be the total number positional parameters in `Type` &mdash;
    required, optional, and rest.

    Let `required` be the number of required positional parameters in `Type`.

    Let `optional` be the number optional parameters in `Type`. (The rest
    parameter is not considered optional.)

    Let `hasRest` be true if `Type` contains a rest parameter.

    Let `optionalArgs` be `arity - required`. This is the number of optional
    parameters that will be provided with arguments at this arity. (It may be
    larger than the total number of optional parameters, but that's OK.)

    Let `hasRestArgs` be true iff `arity - required - optionalArgs > 0`. This is
    true if there are enough arguments left over for the rest parameter.

2.  If `arity < required`, there are not enough arguments for this to be a valid
    call. `Type` has no parameter list at this arity. Abort.

3.  If `optionalArgs > optional` and `hasRest` is false then there are too many
    arguments for this to be a valid call. `Type` has no parameter list at this
    arity. Abort.

4.  At this point, we know the arity is valid. Now we can figure out which
    parameter will be used at each position. Create an empty list of parameters,
    `result`. For each parameter in `positional`:

    1.  If the parameter is required add it to `result`.

    2.  If the parameter is optional and `optionalArgs > 0`:

        1.  Add it to `result`.

        2.  Decrement `optionalArgs`. In cases where there is enough arity for
            some but not all optional parameters, this ensures they are filled
            left-to-right.

    3.  Otherwise, the parameter is the rest parameter. If `hasRestArgs:`

        1.  Add the parameter to `result`.

5.  Return the resulting list of parameters.

A working prototype of the parameter binding and subtyping logic is
[here][prototype].

## Migration

If this proposal did its job correctly, everything in here is non-breaking and
backwards compatible at the language level. Existing method declarations are
valid and fit within a subset of what is now expressible.

In order to take advantage of these features, API designers may want to turn
some named parameters (think "child" in Flutter) into positional parameters or
vice versa. That is a breaking change, but can be phased in by supporting both
for a while:

```dart
SomeWidget(aRequiredParameter, [Widget child2], {@deprecated Widget child}) {
  child ??= child2;
  // ...
}
```

(This is an example of why supporting both optional positional and named is
really handy. It's also a good example of why not allowing positional parameters
to be passed by name is useful. When the old named `child` parameter is removed,
`child2` can be renamed to `child` without breaking any callers since it can
only be passed by position.)

Changing a named parameter to a rest parameter (think "children") is also doable
with a deprecation period:

```dart
SomeWidget(aRequiredParameter, List<Widget> ...children2,
    {@deprecated List<Widget> children}) {
  children ??= children2;
  // ...
}
```

Changing an existing positional parameter to a rest parameter is more difficult.
That is a breaking change. So things like `List.addAll()` will likely never use
rest parameters. That's probably a good thing. In code like:

```dart
var stuff = ...
list.addAll(stuff);
```

It's not necessarily clear what the user even intends. Silently treating that
like a spread is dubious. We should give users some guidance on when to use a
rest parameter versus a regular list-typed parameter. Some heuristics to
consider:

* If the caller thinks of it as passing several arguments to the function, use a
  rest parameter. For example a `hash()` function that can generate a hash code
  given some objects is a good candidate. The caller doesn't think of it as
  passing *a collection* of objects. Instead, they perceive it more like there
  being multiple overloads of `hash()` for different numbers of parameters.

* If function or constructor being called itself feels like a collection, use a
  rest parameter. For example, it feels redundant to pass an explicit *list* of
  children to Flutter's [Column][] class because that class itself is a
  container.

* Higher-level DSL-like APIs are a more natural fit for rest parameters.
  Simpler, more concrete APIs benefit from being more explicit.

* If most callsites would end up containing list literals, then a rest parameter
  is a net improvement to brevity. Conversely, if most callsites would end up
  having to use a spread argument, the rest parameter isn't being helpful.

In some cases, it may be reasonable for a class to support a rest-parameter and
non-rest parameter version of the same operation. For example, we could add
`List.addRest(List<E> elements)`.

## Next Steps

Right now, this proposal is just a draft. The first step is to run it by the
language leads and see what they think. Assuming that's OK, going forward means
gathering more feasiblity and usability data:

*   Talk to the DDC, dart2js, and VM teams to see how supporting the additional
    parameters affects the calling conventions, ABI, and performance of function
    calls.

*   Consider some kind of user study or survey to get data on whether `...` or
    `*` is a better choice for rest/spread.

*   Consider user studies of Flutter's API to see if turning `child` into a
    positional parameter is helpful or not.

*   Likewise, test to see if turning `children` into a rest parameter helps
    or harms.

*   In order to get a sense of how useful rest parameters would be, we can
    scrape some corpora to look for existing rest-like APIs. We can look for
    functions where most arguments are list literals. Or look for declarations
    containing a series of optional positional parameters of the same type and
    similar names, like `foo([Type thing1, Type thing2, Type thing3]).

*   If we're adding a spread syntax, it's natural to allow it inside list and
    map literals as well. I don't do that here because it's orthogonal to this
    proposal, but we should consider writing a separate proposal for that. (I
    wouldn't be surprised if `...` ended up more useful in list literals than it
    is in argument lists.)

## Questions and Alternatives

### Why are rest parameters declared explicitly?

One option to get the most bang for the buck would to say any parameter whose
type is `Iterable<T>` or `List<T>` can implicitly be called using rest
parameters. That way, existing APIs that take those types automatically
"upgrade" to supporting rest parameters.

There's a few problems with this, but a sufficiently fatal one is that an API
may take multiple iterable parameters. If you try to have multiple rest
parameters, it becomes ambigious which argument goes to which parameter:

```dart
method(List<int> ...a, List<int> ...b) {}

method(1, 2, 3, 4);
```

Which numbers get bound to `a` and which to `b`? The safer option is to make
rest parameters explicit. This means there may be a window of time where the
feature isn't as useful as it could be until library maintainers go back and add
`...` to the right APIs, but it's safer and easier to reason about.

### Why not use the same syntax for optional parameters as other languages?

One of Dart's greatest virtues is how familiar and easy to learn it is. We
achieve that mostly by following in the footsteps of existing languages. Our
optional parameter syntax is a case where we didn't do that. In most other
languages, you make a parameter optional simply by giving it a default value:

    ```
     function foo(i = 123)          // JavaScript
          def foo(i = 123)          // Python
          def foo(i = 123)          // Ruby
     function foo($i = 123)         // PHP
         void foo(int i = 123)      // C++
         void Foo(int i = 123)      // C#
          fun foo(i: int = 123)     // Kotlin
    procedure foo(i: integer = 123) // Pascal
          def foo(i: int = 123)     // Scala
         func foo(i: Int = 123)     // Swift
     function foo(i: number = 123)  // TypeScript
    ```

Unfortunately, we can't *always* do that in Dart because optional parameters are
also part of function *types*, not just function *declarations*. In something
like, say:

```dart
typedef TakeOneOrTwo = Function(int one, [int another]);
```

It doesn't make sense to provide a default value, so we can't use the familiar
`= blah` syntax to indicate optional parameters.

Most other languages also don't distinguish between optional positional and
named parameters&mdash;if named parameters are supported, you can usually pass
any parameter by name.

Distinguishing named from positional parameters is a nice feature of Dart. It
gives API authors more control over how the API is used and avoids inadvertently
bleeding parameter names into the public API. It also makes our function
subtyping and override rules more tractable. (C# is *weird* about this.)

So, unlike other languages, we need a way to distinguish named and positional
parameters. And we need a way to indicate optional parameters that doesn't rely
on the presence of a default value.

We could support *both* the typical syntax for optional (positional) parameters
as well as the `[...]` for use in things like typedefs:

```dart
method(int i, int j = 2, {int named}) { ... }

typedef OneOrTwo = void Function(int i, [int j], {int named});
```

But it's not clear that the familiarity and brevity is worth having two ways to
say the same thing.

### Why is a spread operator required?

It seems like a natural way to handle spreading is to say that if argument is a
collection of the rest parameter's type, implicitly spread it. So, like:

```dart
function(List<String> ...args) {}

var stuff = ["a", "b"];
function(stuff);
```

We know that `stuff` is a list of string and it's being passed to a rest
parameter that contains strings so we can just assume the user wants to
implicitly unpack it.

This is how C# and Java work. But those languages also allow overloading by
type, which Dart does not. Dart is becoming *more* of a statically typed
language, but we don't yet rely heavily on types to change runtime semantics.

If, for example, inference were to fail on `stuff` in the above example for some
reason, the meaning of the call to `function()` would change. It also raises
weird questions around which types can be unpacked. Is a `List<Object>` a valid
type for a rest parameter of `List<String>` since Object can be implicitly
downcast to String?

The safest option is to provide a little syntax for the user to make their
intent clear.

### What about required named parameters?

Flutter and many other users would like to support parameters that are passed by
name but *not* optional. This would be particularly nice for Boolean parameters
since the style guide recommends those always by passed by name.

Unfortunately, I wasn't able to come up with a syntax that felt reasonable or
any better than the `@required` annotation currently being used. This is another
feature worth revisiting when non-nullable types are added: A named parameter
whose type is non-nullable and doesn't have a default value is a natural
candidate for becoming a required parameter.

[column]: https://docs.flutter.io/flutter/widgets/Column-class.html
[js rest]: https://github.com/dart-lang/sdk/blob/master/pkg/js/lib/src/varargs.dart
[issue #7056]: https://github.com/dart-lang/sdk/issues/7056
[issue #16253]: https://github.com/dart-lang/sdk/issues/16253
[issue #21406]: https://github.com/dart-lang/sdk/issues/21406
[prototype]: https://github.com/munificent/ui-as-code/blob/master/scripts/bin/parameter_freedom.dart
[so 1]: https://stackoverflow.com/questions/13731631/creating-function-with-variable-number-of-arguments-or-parameters-in-dart
[so 2]: https://stackoverflow.com/questions/16262393/dart-how-to-make-a-function-that-can-accept-any-number-of-args/16266780
