# Parameter Freedom

Loosen restrictions around positional, optional, and named parameters. Add rest
parameters and a spread operator. Let API authors define flexible, expressive
parameter lists that free callers from writing useless boilerplate.

## Motivation

My goal with the "UI as code" work is a holistic set of language changes that
hang together to improve the user experience of the code. In order to make
progress, it's useful to break that into individual proposals that we can work
on independently and incrementally.

Every set of features I've considered so far includes at least three changes to
parameter lists:

### Passing positional arguments after named arguments

If a method takes a big function literal, collection, or other large nested
expression as an argument, it's easiest to read at the end of the argument list.
If the method accepts other named arguments, this forces you to make this
trailing argument named, even if you don't want it to be optional or the name is
pointless. For example:

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

Here, you want the `child` widget to be the last argument because it's larger
than the `style` argument. But it should also be mandatory and the `child` name
doesn't add much value.

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

### Both optional positional and named parameters

Dart allows optional positional parameters or optional named ones, but not
both. When those features were first designed, the language team knew this was
an arbitrary limitation. This restriction causes a couple of problems:

*   **If you want to give a name to one optional parameter, you have to name
    *all* of them.** This can lead to not-very-useful parameter names like
    `child` and `children`. These parameter have to be named, even though the
    name communicates little, because the methods taking them also want to take
    other parameters that are named.

*   **Once a method chooses an optional style, it is stuck with it.** You define
    a method that takes an optional positional parameter and ship the API.
    Later, you want to add another optional parameter. That's a non-breaking
    change. But that parameter really *should* be named. Alas, you can't do
    that. You would have to go back and change the existing parameter to be
    named too, which is a breaking change.

    The language team has a goal to improve the ability to evolve APIs without
    breaking them. This is one of the corners of the language that causes that
    unneeded breakage. Allowing a single method to take both optional positional
    *and* optional named fixes that.

    (See [issue #21406][].)

(See [issue #7056][].)

### Rest parameters

Almost every language has a way to pass an unbounded series of arguments to a
function without having to explicitly create a list or array, usually called
"varargs", "variadic parameters" or "rest parameters". Dart doesn't, which leads
to a large amount of boilerplate `children: [ ... ]` code in Flutter widgets.
This is something Flutter users often complain about.

Because Dart doesn't support rest parameters and JavaScript does, we have to
[work around it in interop][js rest].

(See [issue #16253][], StackOverflow [1][so 1], StackOverflow [2][so 2].)

### Non-trailing optional parameters

Dart currently requires all optional positional parameters to be at the end of
the parameter list. Sometimes this leads to an unnatural parameter order. A
classic example is a function that takes a range with an optional minimum, like:

```dart
int random(int minOrMax, [int max]) {
  // ...
}
```

That weird first parameter name is because what it represents depends on whether
or not the second parameter is passed. The problem is much worse if the two
parameters need to have different types. At that point, you are usually forced
to make both named and throw an exception if the user passes the wrong one.

Individually, these are all fairly minor changes. But given how much code,
especially Flutter UI code, is composed of method invocation, these changes can
have a large impact on the clarity and brevity of a user's program. They
probably won't move the needle&mdash;we should look into more ambitious features
in addition to these&mdash;but they eliminate a large number of small frictions.

Since these changes are intertwined in the same corner of the language's
semantics and grammar, this proposal addresses them all together.

## Proposal

An over-arching goal of this proposal is good performance for ahead-of-time
compiled code. A large fraction of execution time is spent calling functions and
binding parameters to arguments. We want to be able to do as much of the
resolution and binding logic&mdash;determining which argument ends up associated
with which parameter position&mdash;at compile time.

At the same time, we still support dynamic calls and don't want behavior to
diverge if you defer binding to runtime. To achieve that, this proposal ensures
that the runtime types of functions and arguments do not affect the way
parameters are bound. The static type of the function and the arity of the
argument list completely control binding.

The rest of the proposal goes into detail about each change, but here is a quick
introduction to the proposed solutions:

### Passing positional arguments after named arguments

We maintain the rule that arguments are evaluated strictly left-to-right. It's
just that now that may involve evaluating a mixture of positional and named
arguments instead of knowing all of the positional arguments will be evaluated
first.

Implementations already have to deal with the fact that named arguments can
appear in a different order than the named parameters they bind to, so I don't
believe this causes much additional complexity.

### Both optional positional and named parameters

The semantics for positional and named parameters in Dart are orthogonal. (This
is unlike most languages where you can pass any parameter by name or position.)
To support both, we just permit both in a single function.

There may be implementation challenges with this. DDC's function calling
convention (and thus its JS interop API) takes advantage of the fact that a
function cannot have both optional positional and named parameters, and that the
optional positional parameters are all at the end.

Other implementations may have other challenges fitting both kinds of
optional arguments into their calling convention. We'll work with those
teams to see how much of an issue this is.

### Non-trailing optional parameters

We remove the restriction that the `[...]` section must be after all the
required parameters. Instead, it can appear at any point in the positional
argument list, like here:

```dart
int random([int min = 0], int max) {
  // ...
}
```

When calling a method where the optional parameters aren't necessarily at the
end, we rely on the arity of the call&mdash;the number of arguments&mdash;to
determine which parameters are bound and which aren't. With the above, the valid
calls are:

```dart
random(10);    // Uses the default for min and binds max to 10.
random(5, 15); // Binds min to 5 and max to 15.
```

Since we want to support parameter lists with leading or trailing optional
parameters, it's a relatively small step to go to full generality and support
multiple `[...]` sections, with non-optional parameters between them:

```dart
method(int a, [bool b, double c], num d, [String e]) { ... }
```

That, of course, is a pathological example. Almost all real code will contain a
single optional parameter section, usually just a single parameter.

### Rest parameters

To support rest parameters, we define one more kind of positional section in a
parameter list. A rest parameter is an (optional) type annotation followed by
`...` and then a parameter name. For example:

```dart
runProcess(String command, List<String> ...arguments) { ... }

main() {
  runProcess("cat", "file1.txt", "file2.txt");
}
```

### Spread arguments

If you want to expand a collection object into a sequence of rest arguments,
you can use the "spread" operator:

```
var files = ["file1.txt", "file2.txt"];
runProcess("cat", ...files);
```

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
spread to other parameters. In typical cases, there's a single spread that maps
directly to the rest parameter:

```dart
int sum(List<int> ...ints) => ints.fold(0, (a, b) => a + b);

var numbers = [3, 4, 5];
sum(...numbers);
```

It's also fine to mix a spread with regular arguments:

```dart
var numbers = [3, 4, 5];
sum(1, 2, ...numbers, 6, 7);
```

In fact, you can also have multiple spreads, even spreads interleaved with other
non-spread arguments. They just all need to get bound to the rest parameter:

```dart
var numbers = [3, 4, 5];
var more = [8, 9];
sum(1, 2, ...numbers, 6, 7, ...more, 10);
```

In the future, we may add destructuring assignment or pattern matching to Dart.
If that happens, it will likely support a similar feature so this anticipates
that.

### Summary

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

It's not a radical difference, but it's hopefully a real improvement. The
changes here are general enough that they should be useful for a wide variety of
APIs outside of Flutter too. In much greater detail...

## Syntax

I've never been thrilled about Dart's parameter syntax. The square brackets and
curlies are weird and unintuitive. But they're what we have and it's hard to
come up with something better that covers all of the various use cases.

If/when we later add support non-nullable types, I think we should revisit
parameters and consider using the nullability of a parameter to imply
optionality too. In the meantime, this proposal takes a more conservative
approach and builds on the existing syntax.

### Rest parameters

Some languages use a keyword (`params` in C#, `vararg` in Kotlin), some use a
`*` (prefix in Ruby and Python, postfix in Scala), and some use `...` (postfix
in Java, prefix in JavaScript, on its own in C).

Since Dart's syntactic legacy most strongly follows JavaScript and Java, I
prefer `...`. I think it's more familiar and also stands out. If we later add
support for destructuring assignment, that's the syntax we'd likely want to use
for rest arguments there. Since the type annotation is optional, we place the
`...` before the parameter name:

```dart
void concat(List<String> ...arguments) { ... }
```

Note that unlike Java and Scala, a rest parameter does not implicity convert the
type to a collection. You have to explicitly write `List<String>` and not just
`String`. This is verbose, but consistent with other places in Dart. Marking a
function `async` does not implicitly wrap its return type in `Future<___>`.

There's argument that `*` is a better choice for Dart given `sync*` and
`yield*`. A user study would help us choose between the two. I could go either
way. If we switch to `*` for rest, we should do the same for spread.

### Argument lists

There are two changes to the calling side of the grammar:

* Allow positional arguments after named ones.
* Allow spread arguments.

Note that spread is *not* a general expression form. It's only allowed in an
argument list. Here's the grammar:

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

### Parameter lists

We have three changes to parameter lists:

* Allow both optional positional and named parameters.
* Rest parameters.
* Non-trailing optional parameters.

I think the following grammar changes cover them:

```
formalParameterList:
  '(' ')' |
  '(' positionalSections ','? ')' |
  '(' namedParameters ','? ')' |
  '(' positionalSections ',' namedParameters ','? ')' |
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

It is a compile-time error if a parameter list contains multiple rest
parameters. It is a compile-time error if a parameter list contains multiple
adjacent optional parameter sections. (The latter isn't harmful, but we prohibit
it to avoid two ways of expressing the same thing.)

## Definitions and Model

Before we get into the detailed semantics, I want to define a model for
parameters, a few terms, and an algorithm that will be used throughout.

### "Argument"

With the introduction of spread arguments, the definition of "argument" gets
fuzzier. In:

```dart
var elements = [1, 2, 3];
function(...elements);
```

How many arguments are there, one or three? In this proposal, the answer is
"one". An "argument" is a single comma-delimited element in the argument list.
It may or may not be a spread argument. We can query any argument to see if it's
a spread one or not. In this example, `function` takes one spread argument.

After a spread argument is "unpacked" or "spread out", we know longer talk about
"arguments" and talk about "elements" or "values".

### "Overloads"

A function type specifies a signature for how you can call it and a type that
you get in return. We'll ignore return types since they aren't relevant to this
proposal. So:

```dart
function(int a, bool b, String c)
```

Lets you call it like:

```dart
function(1, true, "three")
```

When a function type has optional parameters, you can think of it as specifying
a *set* of "overloaded" signatures, all of which are valid. So:

```dart
function(int a, [bool b, String c])
```

Is conceptually a bundle of three overloads:

```dart
function(int a)
function(int a, bool b)
function(int a, bool b, String c)
```

The rule for binding parameters to arguments is that as long as the argument
list matches one of the function's overloads, it's a valid call to that
function.

For subtyping, the rule is a function must have at least all of the overloads of
the supertype to be a valid subtype. So given:

```dart
function(int a, [bool b, String c])

// Which expands to:
function(int a)
function(int a, bool b)
function(int a, bool b, String c)
```

This is a valid subtype (and thus also a valid method override):

```dart
sub(int a, [bool b, String c, double d])

// Which expands to:
sub(int a)
sub(int a, bool b)
sub(int a, bool b, String c)
sub(int a, bool b, String c, double d)
```

It adds *another* overload, but that's OK. (This is also why adding an
*optional* parameter to a *superclass* method is a breaking change. It adds a
new overload that the subclass overrides may not all support.)

Dart's current restrictions around optional parameters simplify what it means to
"choose an overload" when resolving and type checking a call and when doing
subtype tests between functions. Since the optional arguments are always at the
end, and filled in left-to-right, the presence or absence of an optional
argument never "shifts" any other arguments.

This means that if, say, the second parameter has type String, that is true
across all overloads that accept a second parameter. This lets you type check
calls and subtypes by just walking the parameter list and ignoring overloads and
optional parameters.

When we allow interleaving optional parameters and required ones, we lose that
property:

```dart
function([int a], String b)

// Which expands to:
function(String b)
function(int a, String b)
```

The type of the first parameter depends on which overload is chosen. The
proposal here accommodates that.

### Binding priority

When there aren't enough arguments for all of the parameters a function expects,
some parameters end up unfilled and use their default value. With required
parameters, interleaved optional parameters, and rest parameters, determining
which parameters get which arguments is more complex.

Dart's current principles are:

*   **Required parameters always get arguments.** That's what "required" means.

*   **An optional parameter doesn't get a value unless all optional parameters
    to its left do first.**

This proposal preserves those and adds:

*   **A rest parameter doesn't get any arguments until after all optional
    parameters do.**

You can think of argument binding as happening in two steps:

1.  For each parameter, you figure out *if* it gets an argument.
1.  Then, for each parameter that does get an argument, figure out *which one*
    (or ones for rest) it gets.

We do the first step by giving each parameter a *binding priority*. Binding
priorities start at zero (the first, highest priority) and increase from there:

1.  **Assign each required parameter successive binding priorities from left to
    right.**

1.  **Then each optional parameter from left to right.** These come immediately
    after the required ones in priority, and increase as you go from left to
    right. This way, if only some of the optionals get filled, it's the leftmost
    ones that win.

1.  **Then the rest parameter, if there is one.**

Given a set of arguments, the rule to determine which parameters get arguments
is simple:

* **Any parameter whose binding priority is lower than the number of arguments
  passed wins.** So if you pass three arguments to a function, parameters with
  binding priority 0 through 2 get arguments, and any others won't.

Priority tells us *if* a parameter gets any argument. Next, we decide *which*
arguments go to which parameters. Dart's principle is:

*   **Non-named parameters are bound to arguments in strictly left-to-right
    order.**

Even though we allow optional parameters to appear before required ones, which
means you can have lower *priority* parameters before higher ones, we preserve
this principle. That's why we split it into two phases. First, priority
determines *if* a given parameter gets any arguments. Then we start over and
walk the argument list left-to-right, doling them out to parameters as needed.

We also need to handle the rest parameter. This means a single parameter might
get multiple arguments. Since the rest parameter only gets "extra" arguments,
the number of arguments it claims is always the total number of arguments minus
the number used for optional and required parameters.

### Positional binding algorithm

Here is the full algorithm that binds positional (required, optional, and rest)
parameters to arguments. It takes a parameter signature (a function type), and a
list of positional arguments, some of which may be spread arguments. It returns
a mapping of arguments to parameters. Multiple arguments may be mapped to a
single parameter, and some parameters may get no arguments.

This algorithm is used by both the static and dynamic semantics. When used
statically, the signature is a function's static type, and the list of arguments
is the list of their static types. When used dynamically, the signature is the
function's runtime type and the arguments is the list of argument values.

The algorithm may produce errors. When used for static semantics, these are
compile-time errors. For dynamic semantics, they throw a type error.

1.  Let `args` be the number of positional arguments.

1.  Let `required` be the number of required positional parameters.

1.  Let `optional` be the number of optional positional parameters.

1.  Let `restArgs` be `argCount - required - optional`. This is the number of
    arguments that will get bound to the rest parameter. It may be negative.

1.  If `args < required`, then there are not enough arguments for all
    the required parameters. Error.

1.  If `args > required + optional` and there is no rest parameter, then there
    are too many arguments. Error.

1.  Start at the first positional argument. For each positional parameter:

    1.  If the parameter is the rest parameter:

        1.  Bind the parameter to the next `restArgs` arguments in the argument
            list and advance past them.

        Else if the binding priority of the parameter is less than the number of
        positional arguments:

        1.  If the argument is a spread argument, error. You cannot apply a
            spread argument to a non-rest parameter.

        1.  Bind the parameter to the current argument, and advance to the next
            argument.

        Else the parameter is not bound to an argument.

Here's a (grotesque) example of it in action:

```dart
function(int a, [int b], List<int> ...c, int d, [int e])
// priority: 0       2                4      1       3
```

As you can see, the required parameters have the lowest priority numbers, then
the optionals, then finally the rest parameter. Valid calls at different arities
looks like this:

```dart
//       a  b  c     d  e
function(1,          2)     // a: 1, b: none, c: [],     d: 2, e: none
function(1, 2,       3)     // a: 1, b: 2,    c: [],     d: 3, e: none
function(1, 2,       3, 4)  // a: 1, b: 2,    c: [],     d: 3, e: 4
function(1, 2, 3,    4, 5)  // a: 1, b: 2,    c: [3],    d: 4, e: 5
function(1, 2, 3, 4, 5, 6)  // a: 1, b: 2,    c: [3, 4], d: 5, e: 6
```

As you add more arguments, the optionals get filled in in order. Once those are
all provided for, adding more arguments increases the number that go to the rest
parameter.

## Static Semantics

### Function declaration

The object bound to a rest parameter is automatically created by the
implementation, so its type is restricted. It is a compile-time error for a rest
parameter to have a static type other than `dynamic` or `List<T>` for some `T`.
(We allow `dynamic` mostly to support unannotated rest parameters.)

If the static type of a rest parameter is `List<T>` for some `T`, the *element
type* of the rest parameter is `T`. Otherwise, it is Object.

### Function invocation

When calling a function whose static type we know, we check that the argument
list is valid for the function's parameter list. The binding algorithm does the
heavy lifting. What's left is to make sure the types of the arguments match the
parameters and that rest and spread are treated correctly.

1.  If the function's type is `dynamic`, the invocation is not checked
    statically. Otherwise:

1.  Run the positional binding algorithm using the function's static type and
    the static types of the positional arguments.

1.  For each non-rest positional parameter:

    1.  If the argument the parameter is bound to is a spread argument,
        compile-time error. You cannot spread to non-rest parameters.

    1.  If the argument's type is not assignable to the parameter's type,
        compile-time error.

1.  If there is a rest parameter, for each argument the rest parameter is
    bound to:

    1.  If the argument is a spread argument:

        1.  If the argument is not assignable to `Iterable<T>` where `T` is the
            rest parameter's element type, compile-time error.

        Else (non-spread argument):

        1.  If the argument's type is not assignable to the parameter's
            element type, compile-time error.

1.  Apply the existing static semantics for named arguments/parameters and the
    return type.

### Subtyping

Dart supports calling functions dynamically when nothing is known statically
about the type of the function being called. Even with static types, the runtime
type of the actual function called may be a subtype of the static type of the
invocation.

It is profoundly confusing to users if those don't all behave the same. For
example, say you have:

```dart
range([int min = 0], int max) => print("$min - $max");

range(10); // "0 - 10".
range(3, 8); // "3 - 8".
```

Great. We could conceivably consider that function to be a valid subtype of
`Function(int a, [int b])`. They both accept either one or two parameters. But
consider what happens when you invoke the former through a variable with the
latter's type:

```dart
Function(int a, [int b]) fn = range;
fn(10);
fn(3, 8);
```

We want to be able to *statically* determine which arguments get bound to which
parameters and thus which parameters use their default. Based on the *static*
type of `fn`, we would expect `fn(10)` to bind 10 to the first parameter and use
the default for the second. But that's exactly the opposite of how `range()`
behaves if you call it directly.

To avoid these cases, we restrict the rules around subtyping. The principle is:

*   **A function type is only a subtype of another it supports all of the same
    invocations *and they all bind the same parameter positions to the same
    argument positions*.** In other words, all corresponding parameters need to
    have the same binding priority. The existing subtype rules follow this
    principle.

To determine if function type `Type` is a subtype of function type `Supe`:

1.  If `Supe` has more positional parameters than `Type`, `Type` is not a
    subtype. It needs to accept at least every parameter that `Super` accepts.

1.  For each parameter position in `Supe`:

    1.  Let `pSupe` be the parameter at that position in `Supe`. Let `pType` be
        the parameter at that position in `Type`.

        1.  If `pSupe` is not a subtype of `pType`, `Type` is not a subtype.
            This is the usual contravariant parameter rule.

        1.  If `pSupe` is rest and `pType` is not, or vice versa, `Type` is
            not a subtype.

        1.  If `pSupe` is optional and `pType` is not, `Type` is not a subtype.
            A subtype cannot turn an optional parameter required because it
            would be possible to call it through the supertype and not pass
            the argument.

        1.  If the binding priority of `pSupe` is not the same as the binding
            priority of `pType`, `Type` is not a subtype. This ensures you can't
            get a different argument order when you invoke the same function
            through a supertype as through a subtype.

            *The effective restriction is that required parameters in the
            supertype must usually stay required in the subtype. However, a
            subtype can make one or more required parameters optional if all
            optional parameters in the supertype are after all of its required
            parameters. It's OK for a rest parameter to be anywhere in there.
            This follows the existing Dart rules.*

1.  If `Supe` has a rest parameter and `Type` has more positional parameters
    than `Supe`, `Type` is not a subtype. You can't "add" extra parameters when
    the supertype already has a rest parameter, because those additional
    parameters will consume arguments and shift which arguments get bound to
    the rest parameter.

1.  For each parameter position in `Type` beyond the last parameter position in
    `Supe` (i.e. for the extra parameters `Supe` has at the end):

    1.  If the parameter is required, `Type` is not a subtype. You can only add
        optional parameters and/or a rest parameter.

1.  It the return type of `Type` is not a subtype of the return type of `Supe`,
    `Type` is not a subtype.

1.  Apply the existing function subtyping rules for named parameters.

1.  If we get here, `Type` is a subtype.

*Note: We ignore generic type arguments because they aren't affected by this
proposal.*

This is basically the same subtype logic Dart currently has except that:

*   It handles optional parameters appearing before required parameters. Since
    Dart already requires each optional parameter in a supertype to be
    optional in a subtype, this is a non-breaking extension of that.

*   It handles rest parameters. For a function type to be a subtype, any rest
    parameters must line up.

*   It makes it invalid for a subtype to add any optional parameters if the
    supertype has a rest parameter. Since no functions have rest parameters in
    Dart today, this is also non-breaking.

## Dynamic Semantics

### Function declaration

When a function with a rest parameter is called, the implementation takes the
rest arguments and bundles them into a *rest object* which is the actual object
the rest parameter is bound to. The competing goals for this object are to make
it useful for users in the body of the function, while restricting it so that
implementations have room to optimize its representation (possibly to the point
of not materializing it at all).

To that end, the rest object:

*   Implements `List<T>` where `T` is the rest parameter's element type.

*   May throw a runtime exception on any attempts to modify the object. This
    lets implementations use optimized representations that don't support
    modification.

*   Makes no guarantees about its identity. You may get a rest object that is
    identical to one from another invocation, a different function, or some
    user-visible object. This lets implementations reuse a const empty list in
    cases where no arguments are passed or otherwise reuse objects when
    practical.

Basically, if you are taking a rest parameter, assume you can read from it
inside the body of the function but otherwise treat it as ephemeral.

### Function invocation

This extends the existing behavior of evaluating an invocation's arguments
(16.14.1) and binding parameters to them (16.14.2).

1.  Evaluate the argument expressions (both named and positional) in the order
    that they appear at the invocation. If an argument is a spread argument,
    evaluate the expression after the `...`, but do not yet iterate over the
    resulting object.

1.  Evaluate the function expression or look up the member. Get the runtime type
    of the resulting function.

1.  Run the positional binding algorithm using the function's runtime type and
    the values of the positional arguments.

1.  For each non-rest positional parameter:

    1.  If the argument the parameter is bound to is a spread argument, throw an
        error. You cannot spread to non-rest parameters.

    1.  If the argument's type is not assignable to the parameter's type,
        throw an error.

1.  If there is a rest parameter:

    1.  Create a rest object. Assume the existence of this function which
        appends the given element to the rest object:

        ```dart
        void addToRest(T value) { ... }
        ```

        Here, `T` is the rest parameter's element type. Calling this implies
        a runtime cast to `T`, which may throw a cast error.

    1.  For each `argument` that the rest parameter is bound to:

        1.  If `argument` is a spread argument, add `argument`'s elements to the
            rest object by evaluating:

            ```dart
            for (T element in argument) addToRest(element);
            ```

        1.  Else, add the non-spread value to the rest object by evaluating:

            ```dart
            addToRest(argument);
            ```

    1.  Bind the rest parameter to the rest object.

1.  Bind named parameters to named arguments as usual.

These dynamic semantics align with the static semantics. If the static type of
the function is known and it analyzed without error, then the only runtime
errors that can be thrown are implicit downcast failures when binding parameters
to arguments or when adding an element from the spread argument to the rest
object.

A working prototype of the parameter binding and subtyping logic is
[here][prototype].

## Migration

If this proposal did its job correctly, everything in here is non-breaking and
backwards compatible at the language level. Existing method declarations are
valid and fit within a subset of what is now expressible.

However, library maintainers may wish to change their APIs to take advantage of
these new features. That needs to be done thoughtfully.

### Turning named parameters to positional parameters

In order to take advantage of these features, API designers may want to turn
some named parameters (think `child` in Flutter) into positional parameters or
vice versa. That *is* a breaking change, but can be phased in by supporting both
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

### Turning named parameters to rest parameters

Changing a named parameter to a rest parameter (think `children`) is also doable
with a deprecation period:

```dart
SomeWidget(aRequiredParameter, List<Widget> ...children2,
    {@deprecated List<Widget> children}) {
  children ??= children2;
  // ...
}
```

### Changing list parameters to rest parameters

Changing a positional parameter that takes a list to a rest parameter does not
work. Every existing call would break because those would need to simultaneously
be changed to spread arguments to preserve the same behavior. A method like
`List.addAll()` will likely never use rest parameters.

It would be nice if we could change `print()` to:

```dart
print(List<Object> ...objects);
```

This is theoretically safe because it's not an instance method and every
existing invocation of `print()` is also a valid call to the above function.
However, the above change breaks cases where `print` has been used as a closure,
as in:

```dart
[1, 2, 3].forEach(print);
```

**TODO: Can we safely relax the subtyping rules to accommodate this?**

### When to use rest parameters

We should give users some guidance on when to use a rest parameter versus a
regular list-typed parameter. Some heuristics to consider:

*   If the caller thinks of it as passing several arguments to the function, use
    a rest parameter. For example a `hash()` function that can generate a hash
    code given some objects is a good candidate. The caller doesn't think of it
    as passing *a collection* of objects. Instead, they perceive it more like
    there being multiple overloads of `hash()` for different numbers of
    parameters.

*   If the function or constructor being called itself feels like a collection,
    use a rest parameter. For example, it feels redundant to pass an explicit
    *list* of children to Flutter's [Column][] class because that class itself
    is a container.

*   Higher-level DSL-like APIs are a more natural fit for rest parameters.
    Simpler, more concrete APIs benefit from being more explicit.

*   If most callsites pass list literals, then a rest parameter is a net
    improvement to brevity. Conversely, if most callsites would end up having to
    use a spread argument, the rest parameter isn't being helpful.

In some cases, it may be reasonable for a class to support a rest-parameter and
non-rest parameter version of the same operation. For example, we could add
`List.addRest(List<E> ...elements)`.

## Next Steps

Right now, this proposal is just a draft. The first step is to run it by the
language leads and see what they think. Assuming that's OK, going forward means
gathering more feasiblity and usability data:

*   Talk to the DDC, dart2js, and VM teams to see how supporting the additional
    parameters affects the calling conventions, ABI, and performance of function
    calls.

*   My understanding is that when dart2js compiles a function with optional
    parameters, it generates stub entrypoints for every possible arity. That
    doesn't scale to rest parameters where there is no upper limit to the number
    of parameters. We'll have to work with them and see if it's possible to come
    up with a reasonable compilation strategy and calling convention.

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
    similar names, like:

    ```dart
    foo([Type thing1, Type thing2, Type thing3])
    ```

*   If we're adding a spread syntax, it's natural to allow it inside list and
    map literals as well:

    ```dart
    var numbers = [1, 2, 3];
    var more = [5, 6];
    var everything = [0, ...numbers, 4, ...more, 7];
    ```

    I don't do that here because it's orthogonal to this proposal, but we should
    consider writing a separate proposal for that. I wouldn't be surprised if
    `...` ended up more useful in list literals than it is in argument lists.

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
