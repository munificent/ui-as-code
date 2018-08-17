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
them is valid. Positional parameters are great when the argument is mandatory or
the name is obvious from the method being called. Finally, code tends to be
easiest to read when the largest argument expression is last. In particular, if
a method takes a big function literal, collection, or other large nested
expression as an argument, you really want it to hang off the end.

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

At the point that optional parameters were first designed, the language team
knew this was an arbitrary limitation. Today, DDC's current ABI may make it a
challenge to support both, but it's likely we can fix this.

This restriction causes a couple of problems:

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

Almost every language has a way to pass an unbound series of arguments to a
function without having to explicitly create a list or array&mdash;usually
called "varargs", "variadic parameters" or "rest parameters". Dart doesn't,
which leads to a large amount of boilerplate `children: [ ... ]` code in Flutter
widgets. This is something Flutter users often complain about.

Because Dart doesn't support rest parameters and JavaScript does, we have to
[work around it in interop][js rest].

Real support for rest params also potentially unlocks some performance
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
code&mdash;especially Flutter UI code&mdash;is composed of method invocation,
these changes can have a large impact on the clarity and brevity of a user's
program. They probably won't move the needle&mdash;we should look into more
ambitious features in addition to these&mdash;but they eliminate a large number
of small frictions.

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
but the syntax and semantics are straightforward.

### Non-trailing optional parameters

Non-trailing optional parameters is a little more complex. To enable that, we
remove the restriction that the `[...]` section must be after all the required
parameters. Instead, it can appear at any point in the positional argument list,
like here:

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

### Support rest parameters

To support rest parameters, we define one more kind of positional section in a
parameter list. A rest parameter is an (optional) type followed by `...` and
then a parameter name. For example:

```dart
runProcess(String command, List<String> ...arguments) { ... }

main() {
  runProcess("cat", "file1.txt", "file2.txt");
}
```

If you want to expand a collection object into a sequence of rest arguments,
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

### Rest parameters

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
appropriate collection type. The `...` does not implicitly promote `String` to
`List<String>`.

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
parameters. It is a compile-time error if a parameter list contains multiple
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

The rule for binding parameters to arguments is that as long as the argument
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
*optional* parameter to a *superclass* method is a breaking change. It adds a
new overload that the subclass overrides may not all support.)

This "overload" model will help us reason through the changes in this proposal.

### Supporting both optional positional and optional named parameters

From the language's perspective, this one is easy. The static and dynamic
semantics around positional and named parameters in Dart are disjoint.
(This is unlike most languages where you can pass any parameter by name or
position.) To support both, we just do both in a single function.

From an implementation perspective, there may be challenges. I believe DDC's
function calling convention (and thus its JS interop API) takes advantage of the
fact that a function cannot have both optional positional and named parameters,
and that the optional positional parameters are all at the end.

Other implementations may have other challenges fitting both kinds of optional
arguments into their calling convention. We'll work with those teams to see how
much of an issue this is.

### Non-trailing optional parameters

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

The type of the first parameter depends on which overload is chosen. We also
have to figure out how to handle cases where optional arguments are interleaved
and not all are provided. Consider:

```dart
function([int a], int b, [int c], int d, [int e], int f)
```

If you call it like:

```dart
function(1, 2, 3, 4)
```

Which parameters get bound to arguments and which use their defaults? This turns
out to not be intractable and not much more complex than the current rules. The
details are below.

### Rest parameters

The rest parameter, if there is one, only captures arguments if there are more than enough to cover all of the other required and optional arguments.

We'll get into how arguments are bound to rest parameters below. Assuming the
rest parameter *has* been correctly bound to a set of arguments, then what?

The implementation takes those arguments and bundles them into a *rest object*.
(An optimized implementation may not actually materialize the object, but from
the user's perspective, it conceptually exists).

Since the implementation creates the object, there are some restrictions on what
types are allowed for a rest parameter. It is a compile-time error for a rest
parameter to have a static type other than `dynamic` or `List<T>` for some `T`.
(We allow `dynamic` mostly to support unannotated rest parameters.)

Once the implementation has created the rest parameter object, how does it
behave? The goal is to give users a useful object while also giving
implementation teams as much room to optimize as possible.

To that end, the rest object:

*   implements `List<T>`. If the static type of the rest parameter is `List<T>`
    for some `T`, then the rest parameter object's type has that same type
    parameter. Otherwise, it's `List<Object>`.

*   *may* throw a runtime exception on any attempts to modify the object. This
    lets implementations reuse a const empty list in cases where no arguments
    are passed or otherwise use an optimized representation that doesn't
    support mutability.

*   *may* be the original object that was spread, if all of the rest elements
    come from a single spread argument. In other words:

    ```dart
    var restObj;
    function(List ...rest) {
      restObj = rest;
    }

    var list = [1, 2, 3];
    function(...restObj);
    print(identical(list, restObj));
    ```

    It is implementation-defined whether and when this chooses to print "true"
    or "false". Basically, if you are taking a rest parameter, assume you can
    read from it inside the body of the function but otherwise treat it as
    ephemeral.

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
spread to other parameters. In typical cases, there's a single spread that maps
right to the rest parameter:

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

The process for bundling all of the individual and spread arguments up into the
rest object is fairly straightforward. We create a new rest object and walk
through the list of rest arguments. If the argument is not a spread, we add it
directly to the rest object. Otherwise, we iterate over it and add each element
to the rest object. The resulting object implicitly becomes the value that the
rest parameter is bound to.

So the above code desugars statically to something roughly like:

```dart
var numbers = [3, 4, 5];
var more = [8, 9];
sum(<int>[]
  ...add(1)
  ...add(2)
  ...addAll(numbers)
  ...add(6)
  ...add(7)
  ...addAll(more)
  ...add(10));
```

### Binding parameters to arguments

When there aren't enough arguments for all of the parameters a function expects,
some parameters end up unfilled and use their default value. With required
parameters, interleaved optional parameters, and rest parameters, determining
which parameters get which parameters has the potential to be confusing.

The principles Dart currently has are:

*   Required parameters always get arguments. That's what "required" means.

*   An optional parameter doesn't get a value unless all optional parameters to
    its left do first.

*   Parameters are bound to arguments in strictly left-to-right order.

This proposal preserves those principles and adds one more:

*   A rest parameter doesn't get any argument unless all optional parameters do.

You can think of it as running in two phases:

1.  First, you figure out *which* parameters get arguments.
2.  Then given that set, you run through them in order and hand out arguments.

#### Binding priority

We do step one by giving each parameter a *binding priority*. Required
parameters take first priority, then optional, then rest (hence the name).

More precisely:

*   The binding priority of a required parameter is its position in the list of
    required parameter. They get the lowest numbers because they have first
    priority.

*   The binding priority of an optional parameter is its position in the list of
    optional parameters plus the number of required parameters. These come
    immediately after the required ones in priority, and increase as you go from
    left to right. This way, if only some of the optionals get filled, it's the
    leftmost ones that win.

*   The binding priority of the rest parameter is the number of parameters minus
    one. Finally, the rest parameter always gets a last priority, one greater
    than all the others.

These rules assign each parameter a unique priority number starting at zero
(first priority) and increasing from there. Given a set of arguments, the rule
to determine which parameters will get an argument is simple:

* **Any parameter whose binding priority is less than the number of arguments
  passed wins.** So if you pass three arguments to a function, parameters with
  binding priority 0 through 2 will get arguments, and any others won't.

#### Binding order

This tells us *if* a parameter gets an argument. Next, we decide *which*
arguments go to which parameters. That's simpler: we walk the argument lists and
parameter lists in parallel, skipping over any parameter that doesn't have
enough priority. Each parameter gets bound to the corresponding argument.

We also need to handle the rest parameter. Since the rest parameter only gets
"extra" arguments, the number will always be the total number of arguments minus
the number that get used for optional and required parameters. So, if a function
takes 2 required parameters, 3 optional, and you pass it 9 arguments, the rest
parameter gets 4 of them. So, when we hit the rest parameter, we take that many
arguments and then move onto the next parameter.

Here's a (pathological) example of the whole thing:

```dart
function(int a, [int b], List<int> ...c, int d, [int e])
// priority: 0       2                4      1       3
```

As you can see, the required parameters have the lowest numbers, then the
optionals, then finally the rest parameter. So if you call this with just two
arguments, only `a` and `d` have low enough binding priority to capture those
two arguments.

Valid calls at different arities looks like this:

```dart
//       a  b  c     d  e
function(1,          2)     // a: 1, b: null, c: [],     d: 2, e: null
function(1, 2,       3)     // a: 1, b: 2,    c: [],     d: 3, e: null
function(1, 2,       3, 4)  // a: 1, b: 2,    c: [],     d: 3, e: 4
function(1, 2, 3,    4, 5)  // a: 1, b: 2,    c: [3],    d: 4, e: 5
function(1, 2, 3, 4, 5, 6)  // a: 1, b: 2,    c: [3, 4], d: 5, e: 6
```

As you add more arguments, the optionals get filled in in order. Once those are
all provided for, adding more arguments increases the number that go to the rest
parameter.

Note, that the `1`, `2`, `3`, etc. argument values are always in order in the
comments after each call up there. Priority may cause you to *skip* a parameter
that doesn't get a value, but it never reorders the arguments.

### Parameter binding algorithm

Dart is mostly a statically-compiled language and is very focused on
performance. A very large fraction of execution time is spent calling functions
and binding parameters to arguments. If we introduce too much dynamism to that,
we can slow down all Dart code.

To avoid that, even as we make parameter signatures more flexible, we want to be
able to do as much of the resolution and binding logic&mdash;determining which
argument ends up associated with which parameter position&mdash;at compile time.
That means the binding logic should only rely on information known statically:
the number of positional arguments in the invocation, and the static type of the
function being called.

With the binding priority defined, the process to map a list of positional
arguments to the parameter list of a function is fairly straightforward, even
when taking into account optional and rest parameters.

1.  Let `required` be the list of required positional parameters.

2.  Let `optional` be the list of optional positional parameters.

3.  Let `argCount` be the number of positional arguments.

4.  If `argCount < required`, then there are not enough arguments for all
    the required parameters. Compile-time error.

5.  **Handle rest and spread parameters.** If there is a rest parameter:

    1.  Let `restCount` be the `argCount - required.length - optional.length`.
        This is the number of extra arguments that will get bound to the rest
        parameter. It may be negative.

    2.  If `restCount` is non-negative, then:

        1.  Let `restParam` be the index of the rest parameter in the list of
            positional parameters.

        2.  Extract the rest arguments from `restParam` to `restParam +
            restCount` and replace them with the result. (See below.)

        Else (no rest arguments):

        1.  Bind the rest parameter to an unmodifable empty instance of `List<T>`
            where `T` is the type specified in the declaration of the rest parameter,
            if any.

    Else (no rest parameter):

    1.  If `argCount > required + optional`, then there are too many arguments.
        Compile-time error.

6.  If there are any remaining spread arguments, it means they weren't bound to
    a rest parameter. Compile-time error.

7.  **Assign arguments to parameters.** At this point, we know the invocation is
    valid. Now we can assign argument positions to parameters. Start with the
    first positional argument. For each positional parameter:

    1.  If the binding priority of the parameter is less than the number of
        positional arguments (after mutating the list to handle the rest args
        above):

        1.  Bind the parameter to the current argument, and advance to the next
            argument.

        Else:

        1.  Bind the parameter to its default value.

8.  **Bind named parameters.** Do the normal Dart logic for handling named
    arguments and parameters.

9.  **Type check.** Now that we have bound each argument to a parameter, type
     check them as usual.

#### Extracting rest arguments

Now we know the argument list has no more elements than there are parameters.
More precisely:

1.  Create a *rest object* (see above for details on its type).

2.  For each argument in the list of rest arguments:

    1.  If the argument is a spread argument:

        1.  If the static type of the argument does not implement `Iterable`
            (and is not `dynamic`), compile-time error.

        2.  If the static type of the argument implements `Iterable<T>` for a
            `T` that is not assignable to the rest object's element type,
            compile-time error.

        3.  Spread the argument using `iterator`. For each returned element, add
            it to the rest object.

        Else (non-spread argument):

        1.  Add it to the rest object.

4.  Remove the rest elements from the argument list and replace them with the
    rest object.

**TODO: Be more precise about specifying argument expression evaluation order
and when spread expressions are evaluated.**

### Function subtyping

Dart supports calling functions dynamically when nothing is known statically
about the type of the function being called. Even with static types, the runtime
type of the actual function called may be a subtype of the static type of the
invocation.

It is profoundly confusing to users if those don't all behave the same. For
example, say you have:

```dart
random([int min = 0], int max) => print("$min - $max");

random(10); // "0 - 10".
random(3, 8); // "3 - 8".
```

Great. We could conceivably consider that function to be a valid subtype of
`Function(int a, [int b])`. After all, they both take either one or two
parameters. But consider what happens when you invoke the former through a
variable with the latter's type:

```dart
Function(int a, [int b]) fn = random;
fn(10);
fn(3, 8);
```

We want to be able to *statically* determine which arguments get bound to which
parameters and thus which parameters use their default. Based on the *static*
type of `fn`, we would expect `fn(10)` to bind 10 to the first parameter and use
the default for the second. But that's exactly the opposite of how `random()`
behaves if you call it directly.

To avoid these cases, we restrict the rules around subtyping. A function type is
only a subtype of another it supports all of the same invocations *and they all
bind the same parameter positions to the same argument positions*. In other
words, all corresponding parameters need to have the same binding priority. In
practice, this means the subtype rules are pretty similar to Dart's current
rules.

A function type contains a (possibly empty) ordered list of *positional
parameters*. Each positional parameter has a type and may be optional or
required. One required parameter may be a *rest* parameter. A function type also
contains a (possibly empty) set of *named parameters*. Each named parameter has
a *name* (obviously) and a type.

I'm ignoring generic type arguments because they aren't affected by this
proposal. To determine if function type `Type` is a subtype of function type
`Supe`:

1.  If `Supe` has more positional parameters than `Type`, `Type` is not a
    subtype. It needs to accept at least every parameter that `Super` accepts.

2.  For each parameter position in `Supe`:

    1.  Let `pSupe` be the parameter at that position in `Supe`. Let `pType` be
        the parameter at that position in `Type`, if any.
        
        1.  If there is no such parameter in Type, `Type` is not a subtype.

        1.  If the type of `pSupe` is not a subtype of the type of `pType`, 
            `Type` is not a subtype.
            This is the usual contravariant parameter rule.

        3.  If `pSupe` is rest and `pType` is not, or vice versa, `Type` is
            not a subtype.

        2.  If `pSupe` is optional and `pType` is not, `Type` is not a subtype.
            A subtype cannot turn an optional parameter required because it
            would be possible to call it through the supertype and not pass
            the argument.

        3.  If the binding priority of `pSupe` is not the same as the binding
            priority of `pType`, `Type` is not a subtype. This ensures you can't
            get a different argument order when you invoke the same function
            through a supertype as through a subtype.

            *The effective restriction is that required parameters in the
            supertype must usually stay required in the subtype. However, a
            subtype can make one or more required parameters optional if all
            of them occur immediately before the first optional parameter
            of the supertype. It's OK for a rest parameter to be anywhere in there.
            This follows the existing Dart rules.*

3.  If `Supe` has a rest parameter and `Type` has more positional parameters
    than `Supe`, `Type` is not a subtype. You can't "add" extra parameters when
    the supertype already has a rest parameter, because those additional
    parameters will consume arguments and shift which arguments get bound to
    the rest parameter.

3.  For each parameter position in `Type` beyond the last parameter position in
    `Supe` (i.e. for the extra parameters `Type` has at the end):

    1.  If the parameter is required, `Type` is not a subtype. You can only add
        optional parameters and/or a rest parameter.

4.  It the return type of `Type` is not a subtype of the return type of `Supe`,
    `Type` is not a subtype.

5.  Apply the existing function subtyping rules for named parameters.

6.  If we get here, `Type` is a subtype.

This is basically the same subtype logic Dart currently has except that:

*   It handles optional parameters appearing before required parameters. Since
    Dart already requires each optional parameter in a supertype to be
    optional in a subtype, this is a safe extension of that.

*   It handles rest parameters. For a function type to be a subtype, any rest
    parameters must line up.

*   It makes it invalid for a subtype to add any optional parameters if the
    supertype has a rest parameter. Since no functions have rest parameters in
    Dart today, this is also safe.

A working prototype of the parameter binding and subtyping logic is
[here][prototype].

## Migration

If this proposal did its job correctly, everything in here is non-breaking and
backwards compatible at the language level. Existing method declarations are
valid and fit within a subset of what is now expressible.

However, library maintainers may wish to change their APIs to take advantage of
these new features. That needs to be done thoughtfully.

#### Turning named parameters to positional parameters

In order to take advantage of these features, API designers may want to turn
some named parameters (think "child" in Flutter) into positional parameters or
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

#### Turning named parameters to rest parameters

Changing a named parameter to a rest parameter (think "children") is also doable
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
be changed to spread arguments to preserve the same behavior. So a method like
`List.addAll()` will likely never use rest parameters. That's probably a good
thing. In code like:

```dart
var stuff = [1, 2, 3];
list.addAll(stuff);
```

It's not necessarily clear what the user intends. Silently treating that like a
spread is dubious.

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

#### When to use rest parameters

We should give users some guidance on when to use a rest parameter versus a
regular list-typed parameter. Some heuristics to consider:

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
