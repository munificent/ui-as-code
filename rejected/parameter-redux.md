# Parameters Redux

**This proposal is fatally flawed. A key goal was to have it be non-breaking,
but unifying named and positional parameters breaks subtyping and method
overriding.**

Consider:

```dart
class A {
  foo({int a, int b}) {}
}

class B extends A {
  // Note swapped names.
  foo({int b, int a}) => print("$a $b");
}

main() {
  B b = B();
  b.foo(a: 1, b: 2);

  A a = b;
  a.foo(a: 1, b: 2);
}
```

This prints "1 2" twice today, which is what users expect. This is because the
parameter *names* are part of the invocation and the parameter signature. They
really are passed by name and not position.

This proposal says that the argument names are statically desugared to
positional arguments. But, statically, we only see the names of the parameters
in *A* and not their flipped counterparts. So, with this proposal, this would
print "1 2" then "2 1".

There are likely other problems in establishing a subtype relation with the
optional and rest parameters, but the above is sufficiently bad.

---

For the "UI as code" work, my goal is a holistic package of language changes
that hang together and harmoniously improve the user experience of the code.
But, in order to make progress, it's useful to break that package out into
individual proposals that we can work on independently and incrementally.

**TODO: interleaving named and positional args**
**TODO: talk about left-to-right evaluation?**
**TODO: spread operator?**

Every set of features I've considered so inevitably seems to include at least
two changes to parameter lists:

*   **Allow both optional positional and optional named parameters.** At the
    point that optional parameters were first designed, we knew this was an
    arbitrary limitation. Today, DDC's current ABI may make it a challenge to
    support both, but it's likely we can fix this.

    The current restriction this causes a couple of problems:

    *   **If you want to give a name to one optional parameter, you have to name
        *all* of them.** This can lead to not-very-useful parameter names like
        `child` and `children`. Because methods taking those have parameters
        that should be named, and because these parameters are optional too,
        they have to be named as well, even though the name communicates little.

    *   **Once a method chooses an optional style, it is stuck with it.** You
        define a method that takes an optional positional parameter and ship the
        API. Later, you want to add another optional parameter. That's a
        non-breaking change. But that parameter really *should* be named. Alas,
        you can't do that. You have to go back and change the existing parameter
        to be named too, which is a breaking change.

        The language team has a goal to improve the ability to evolve APIs
        without breaking them. This is one of the corners of the language that
        causes that unneeded breakage. Allowing a single method to take both
        optional positional *and* optional named fixes that.

        (See [issue #21406][].)

    Assuming we can solve the ABI problems in DDC, supporting this is as close
    to a pure win as anything in languages ever is.

    (See [issue #7056][].)

*   **Rest parameters.** Most languages have a way to pass a unbound series of
    arguments of the same type to a method without having to explicitly create a
    list or array, usually called "varargs", "variadic parameters" or "rest
    parameters". Dart doesn't, which leads to a large amount of boilerplate
    `children: [ ... ]` code in Flutter widgets. This is something Flutter users
    often complain about.

    Because Dart doesn't support this and JavaScript does, we have to [work
    around it in interop][js rest].

    Having real support for rest params also potentially unlocks some
    performance improvements since the compiler can usually tell that the
    synthesized list is not mutated elsewhere.

    (See [issue #16253][], StackOverflow [1][so 1], StackOverflow [2][so 2].)

It's straightforward to extend the existing parameter syntax to support the both
optional positional and named. I had much more trouble coming up with a syntax
rest parameters that felt natural to me. Because Dart splits the parameter list
into three "sections" (required, optional, and named), it's not obvious where
the rest parameter should go, or how it should look. Does it go inside the
square or curly brackets? Outside? Before? After? Because the current syntax is
unlike any other language, there is no prior art or safe path to follow.

This made me ask: If we're have to touch the parameter syntax anyway, should we
try to improve it in a number of ways? There is a long list of issues and
improvements users have pointed out:

*   **The current syntax is unfamiliar.** One of Dart's greatest virtues is how
    familiar and easy to learn it is. We achieve that mostly by following in the
    footsteps of existing languages. Our optional parameter syntax is a case
    where we didn't do that. In most other languages, you make a parameter
    optional simply by giving it a default value:

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

    There's variation in how type annotations are written, if any. But the
    syntax for optional parameters, in every mainstream language I could find
    that supports optional parameters, is a simple `= <value>`.

    In Dart, we have this weird square bracket and curly brace syntax. In
    addition to being hard to format well, it's foreign and opaque. You would
    think this is mainly a concern of API authors, but API users must also learn
    the syntax before they're able to read docs. You need to know what the curly
    braces mean before you can [create a Duration][].

    (See [issue #6496][].)

*   **Support passing required parameters by name.** This is a long-requested
    feature. Because the language doesn't directly support it, Flutter uses a
    `@required` annotation. That sort of works, but can confuse users when they
    don't realize they need to import a package to access that annotation.

    We [encourage users to make Boolean parameters named][named bool], but that
    forces the parameter to be optional as well, even if the API designer
    doesn't want that. There's no way for them to get the readability of a named
    argument while also getting the explicitness of a required parameter.

    (See [issue #4188][].)

*   **Treat passing `null` explicitly as equivalent to not passing an
    argument.** Dart initially had a `?` syntax to tell if an argument had been
    passed or not. In theory, this lets you forward optional arguments from one
    method to another, but it has combinatorial overhead when used for named
    parameters.

    That syntax was removed, but there is a vestigial feature that passing
    `null` explicitly does *not* use the default value. This is a common trap
    that users fall into. They try to forward optional arguments from one method
    to another and discover to their dismay that an absent argument does not
    have its default used.

    A cleaner, simpler (though slightly less expressive) model is to fill in the
    default value both when the argument is omitted *and* when `null` is
    explicitly passed.

    (See [issue #33918][].)

*   **Unify positional and named parameters.** Many other languages treat named
    and positional parameters uniformly -- it's a choice at the callsite whether
    to pass a given argument by position or by name. Dart makes that explicit.

    There are advantages to keeping the distinction explicit:

    *   Dart already works this way.

    *   It gives the API designer more control over how the API is used. For
        example, they can ensure a Boolean parameter is always passed by name.

    *   It ensures parameter names don't leak into the public API without the
        API designer's consent. In practice, this doesn't seem to be a huge
        concern. The parameter names are part of the API's documentation, and
        other languages do this without undue pain.

    Unifying provides a few advantages:

    *   Most other languages with optional parameters work this way. We can use
        syntax and semantics users are already familiar with.

    *   It's significantly simpler to design a parameter syntax because it
        doesn't have to distinguish the two forms as well as also
        distinguishing required versus optional, rest params, etc.

    There are real trade-offs on this one and it's not clear which is the "best"
    path. For this proposal, I chose to unify in part because I haven't been
    able to come up with a good syntax to distinguish the two.

    (See [issue #6496][].)

*   **Allow optional parameters before required parameters.** In most APIs, it's
    fine to force all the optional parameters to the end of the argument list.
    However, sometimes this leads to an unnatural parameter order. This is
    exacerbated by the lack of overloading in Dart.

    A classic example is a function that returns a random integer in a given
    range. You can give it one argument to return a number between 0 and that
    maximum. Or you can pass two arguments, a min and max. In Dart, that looks
    like:

    ```dart
    int random(int minOrMax, [int max]) {
      // ...
    }
    ```

    That weird first parameter name is because what it represents depends on
    whether or not the second parameter is passed. The problem is much worse if
    the two parameters need to have different types. At that point, you are
    usually forced to make both named and throw an exception if the user passes
    the wrong one.

*   **Remove support for `var` and `final` in parameters.** It's unclear why
    `var` was ever supported. It's virtually unknown, and confuses users on the
    rare times they do run into it. It accomplishes nothing you can't already do
    more clearly by using `dynamic` or just omitting the type. It also sits on a
    piece of syntax that might be useful for some other feature (such as output
    parameters or implicitly declaring fields in a constructor for data
    classes).

    Allowing `final` is arguably useful, but practically worthless.

## Syntax

If you put all of the above together, ideally, parameter lists support:

*   Required and optional parameters, in any order.
*   Any argument can be passed by name, which means the signature does not need
    to distinguish named and positional parameters.
*   Potentially a single rest parameter.
*   For optional parameters, the ability to specify a default value.

### Optional parameters

Those are the same requirements that many other languages have, and indeed we
can use the same syntax for defining optional parameters simply by specifying
the default value. Here's a few before and after examples:

```dart
// Before:
const SectionTitle({
  Key key,
  @required this.section,
  @required this.scale,
  @required this.opacity,
});

// After:
const SectionTitle(
  Key key = null,
  this.section,
  this.scale,
  this.opacity,
);

// Before:
FormatResult writeLines(int firstLineIndent,
    {bool isCompilationUnit, bool flushLeft}) {
  isCompilationUnit ??= false;
  flushLeft??= false;
  // ...
}

// After:
FormatResult writeLines(int firstLineIndent,
    bool isCompilationUnit = false, bool flushLeft = false) {
  // ...
}

// Before:
int random(int minOrMax, [int max]) {
  if (max == null) {
    max = minOrMax;
    min = 0;
  }
  // ...
}

// After:
int random(int min = 0, int max) {
  // ...
}
```

The `= null` is the main downside I see. On the other hand, it is familiar and
explicit. If we later add non-nullable types, there is the potential to treat
nullable parameters as implicitly optional and not require the `= null`.

Aside from that case, this is shorter and more familiar than the current syntax.

### Rest parameters

For rest parameters, there isn't as well-established of a tradition. Some
languages use a keyword (`params` in C#, `vararg` in Kotlin), some use a `*`
(prefix in Ruby and Python, postfix in Scala), and some use `...` (postfix in
Java, prefix in JavaScript).

Since Dart's syntactic legacy most strongly follows JavaScript and Java, I went
with `...`. Figuring out *where* to place it is a little harder. Scala and Java
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

It's a syntax error for a parameter list to have more than one rest parameter.

### Grammar

That's basically it for syntax. A parameter can have a default value, or it can
have a `...` to be a rest parameter. This should work with the existing grammar
for parameters, including field and function-typed parameters, with the
restriction that a function-typed parameter cannot be a rest parameter. That
wouldn't please the type checker anyway, so it's fine to restrict it
syntactically. The grammar is:

```
parameterList:
  '(' parameters? ')' ;

parameters:
  parameterWithDefault ( ',' parameterWithDefault )* ','? ;

parameterWithDefault:
  parameter ( '=' expression )? ;

parameter:
  functionSignature ( '=' expression )?
  | metadata 'covariant'? type? '...'? identifier;
```

This is an entirely new syntax for declaring a parameter list, disjoint with the
old notation. You cannot mix this with old-style `[...]` and `{...}` parameter
lists. Like the new function type syntax, you pick one or the other. (We'll get
to migration later.)

## Semantics

The syntax is easy. The semantics are where it gets interesting. Freely mixing
required, optional, and rest parameters has the potential to be very
complicated. The simple cases, which are what users mostly care about, are
straightforward. But we need to ensure it doesn't breakdown in complex cases.

We *could* simply rule them out by adding restrictions like "the rest parameter
must come last". I think that's the wrong approach. My experience is that any
time we artificially constrain a design to simplify it, the constraint ends up
chafing:

* Not allowing constructors or super calls in mixins.
* Not allowing both optional positional and optional named parameters.
* Bouncing to the event loop before the first await.

Simplicity *is* vital, but it's best when it falls out naturally, and not when
it's something we've forcibly applied by rejecting valid user scenarios.

### Applying arguments to parameters

Where the rubber meets the road is when an argument list is applied to a
signature. The procedure I describe here is the same as Ruby 1.9, which has
parameter lists that work similar to what I propose.

The basic principles are:

*   Binding arguments to parameters can be done entirely statically. Actual
    values do not affect which arguments are associated with which parameters.

*   Static types do not affect which arguments are bound to which parameter.

*   Positional arguments are mapped to parameters strictly left-to-right.

*   Required parameters take precedence over optional parameters.

*   Optional parameters take precedence over rest parameters.

Applying an invocation's argument list to a signature's parameter list happens
in two phases. First is a static resolution process. It determines if a list of
arguments is valid for the signature of the method being invoked, and which
arguments are bound to which parameters. It only needs access to information
known statically from the method signature and the callsite:

*   The parameter list of the method. For each parameter, its name and whether
    it is a rest parameter or has a default value, or neither.
*   *positionalArgCount*, the number of positional arguments.
*   *namedArgs*, the set of the argument names.
*   The static types of each argument.

1.  **Bind named arguments.** For each argument name in *namedArgs*:

    1.  If an argument with that name as already been bound, error.
    2.  If there is no parameter with that name, error.
    3.  Otherwise, bind this argument to that parameter.

2.  **Bind positional arguments.**

    1.  Let *positionalParams* be the number of remaining parameters that
        were not bound to named arguments.

    2.  Let *requiredParams* be the number of remaining parameters that do not
        have default values.

    3.  Let *optionalParams* be the number of parameters that do.

    4.  If *requiredParams* > *positionalArgCount*, then there are not enough
        arguments for all the required parameters. Error.

    5.  If there is not a rest parameter and *positionalArgCount* >
        *requiredParams* + *optionalParams*, then there are too many arguments.
        Error.

    6.  Let *restArgs* be *positionalArgCount* - *requiredParams* -
        *optionalParams*. (It may be less than zero.)

    7.  At this point, we know the invocation is valid. Now we can assign
        argument slots to parameters. Start with the first positional argument.
        For each parameter that was not bound to a named argument:

        1.  If the parameter is required or is optional and we have not run out
            of arguments yet, bind it to the current argument and advance to the
            next one.

        2.  If the parameter is the rest parameter:

            1.  If *restArgs* is greater than zero, then bind that many
                arguments to the rest parameter and advance past them.

            2.  Otherwise, the rest parameter gets no arguments and will be an
                empty list.

        3.  Otherwise, the parameter is not bound to an argument.

3.  **Type check.** Now that we have bound each argument to a parameter, type
    check them as usual.

This either produces a static error in which case the call is invalid, or it
produces a binding that maps argument positions to parameters.

At runtime, there isn't much left to do:

1.  For each parameter:

    1.  If a non-`null` argument is bound to the parameter, use that value.

    2.  Otherwise, use the parameter's default value.

Another way to say all this is that the compiler should be able to desugar the
call to a straight series of positional arguments and an explicitly reified
collection for the rest parameter.

A working prototype of the above logic is [here][prototype].

### Type-checking rest arguments

The previous section covers most of how rest parameters are handled and
arguments bound to them. There are a couple more pieces to talk about:

When declaring a rest parameter, its type must be assignable to `List<T>` for
some `T`. Usually it *is* `List<T>`, but you can do `Iterable<T>`, `Object`, or
`dynamic` if that makes you happy.

**TODO: Could make it an error to use any type other than List or Iterable.**

The *element type* of the rest parameter is inferred from the above type. If the
type is `List<T>` or `Iterable<T>`, the element type is `T`. If the parameter
type is `Object`, the element type is `Object`. Otherwise, it is `dynamic`.

When type-checking the argument list, every argument that ends up bound to the
rest parameter must be a type that is assignable to element type.

At runtime, the rest parameter will always be bound to an object that implements
`List<T>` where `T` is the element type. If no rest arguments are passed, the
list will be empty. The object may be an implementation-specific class that
implements `List<T>`. Much like the `List<T>` passed to `main()`, it may be an
immutable list that throws exceptions on attempts to modify it. The intent is to
give implementations freedom to choose an efficient representation for this.

### Non-trailing rest arguments

The semantics restrict a signature to only a single rest parameter, but they
don't force it to be the *last* parameter. In practice, most of the time it is.
We can allow it earlier without much additional complexity, and doing so has a
couple of advantages.

It's fairly common for a method to accept a large function or collection
literal. Think `test()` in the test packages, or `children` or `child` in many
Flutter APIs. Because that argument is large and block-like, you usually want it
to appear last. If we forced the rest parameter to be last, this would prevent
you from also using this idiom.

At some point, we may add destructuring assignment to Dart. That likely includes
destructuring lists. For that cases, it's often useful to peel off a couple of
leading and trailing elements in the collection, like:

```dart
var sortedActors = [...];
var [best, ...others, worst] = actorsSortedByPerformance();
print("The Oscar goes to $best");
print("The Razzie goes to $worst");
```

Some languages completely unify pattern-matching, destructuring, and parameter
lists. I don't know if we'll go that far, but it helps users to use the same
syntax for both when we can.

### Subtyping and overriding

**TODO**

## Migration

Parameter lists and method invocations are the very core of Dart. There are
millions of method declarations and even more calls to them. We can't ship this
feature if it breaks those.

Fortunately, if this proposal works like I intend, it is *not* a breaking
change. Like the new funtion type syntax, the new `part of` directive, and
optional `new`/`const`, we should be able to support both the old and new
parameter syntax simultaneously. All existing declarations and calls continue to
work the way they do today.

Places where the old and new syntax overlap -- methods with only required
parameters -- have the same semantics either way.

While the new semantics are simpler than the old behavior in some ways because
they unify named and positional parameters, we can reinterpret the existing
method declarations in terms of it. Any optional parameter in an existing
method -- positional or named -- is simply treated as "optional".

Likewise, existing invocations are entirely valid new-style invocations as well.
They simply don't take advantage of all of the affordances they could -- they
never pass a required argument by name, etc.

Over time, users can migrate their method declarations to the new syntax. They
can also take advantage of the new flexibility in their invocations. In fact,
they can do this even when calling methods still declared using the old syntax.
With this proposal, this becomes valid:

```dart
takePositional([arg]) {}
takeNamed({named}) {}

main() {
  takePositional(arg: "by name");
  takeNamed("positional");
}
```

We will provide tools like `dartfmt --fix` to automatically convert old-style
parameter lists to the new notation. Users need to be a little careful when
running them because of the changed behavior around default values. But,
otherwise, it's a simple mechanical change.

### Default values

The above semantics handle both existing old-style parameters and invocations
and the new more expressive ones. The only wrinkle is around handling `null`
arguments and default values. To avoid breaking existing code, we need to track
whether a parameter treats `null` as "absent argument" ("new style") or not
("old style").

To address that argument binding rules become:

1.  For each parameter:

    1.  If a non-`null` argument is bound to the parameter, use that value.

    2.  *NEW:* If a `null` argument is bound to an old-style parameter, use
        `null`.

    3.  Otherwise, use the parameter's default value.

This does not affect the subtyping relation. The runtime behavior of the default
value is essentially an implementation detail of the *body* of the method, not a
property of its signature.

### Mirrors

One place where things might get hard is the mirrors API. That API very directly
exposes the split between optional named and optional positional parameters.

We may be able to evolve that API to handle the new unified optional parameters,
or it may be feasible to making breaking changes to this API.

## Alternatives

This is a pretty ambitious change to a fundamental part of the language. I
believe it is overall a significant improvement. It makes us *more* familiar
while at the same time increasing expressiveness and generality. It's rare that
we are able to do that.

At the same time, it's risky and difficult. While I propose a number of changes
here in a single batch because they all touch the same part of the grammar, it
is possible to subset this proposal if it turns out to be too ambitious.

Maintaining the current behavior around `null` and default values is one
candidate where we can reduce the cost of this proposal without interfering with
other parts of it. However, I also think that's one of the most practically
useful parts of the proposal. Default values are basically broken in Dart today.

Unifying named and optional parameters is likely the contentious issue. That's a
place where the current behavior is deliberate and has some real merit. I think
it's an overall improvement to unify them, but if that's too difficult, we might
be able to keep them separate and salvage the rest of the proposal.

That would involve coming up with some kind of syntax to express which
parameters are positional, named, optional, required, and rest. If we want to
allow them to appear in any order as well, that may be very difficult.

## Next Steps

This is currently somewhere between a draft and a strawman. Maybe an aspiration. The next step is working with the language leads to see if it's something worth putting more team time into.

If so, the next steps are gathering empirical data to help us tell if we're on
the right track. A few experiments I can think of running:

*   User studies of mixed optional, required, and rest parameters. Given a
    parameter signature and an argument list, which arguments do they expect to
    be bound to which parameters? This can be tricky in complex cases like:

    ```dart
    method(int a, int b = 1, int c, List<int> ...d, int e)
    ```

    Do users intuit the rules we have?

*   User studies of the new parameter syntax to see if they can understand that
    giving a parameter a default value implicitly makes it optional. Likewise,
    understanding how the same parameter can be passed by position or by name.
    I'm not too worried about this since the proposal is closer to most existing
    language than Dart's current behavior, but it may be worth looking at.

*   Is `= null` too verbose of a way to indicate an optional parameter in the
    common case where that's the default value? See if there's a way we can do a
    user study or survey. If it's problematic, we can investigate a shorthand
    for it.

*   Run tests to determine how many parameters rely on an explicit `null`
    meaning "do not use the default value". We can hack one or more of our
    compilers to treat all `null` optional arguments as equivalent to absent
    and see how many tests break when run on a large corpus.

[create a duration]: https://api.dartlang.org/stable/2.0.0/dart-core/Duration/Duration.html
[js rest]: https://github.com/dart-lang/sdk/blob/master/pkg/js/lib/src/varargs.dart
[named bool]: https://www.dartlang.org/guides/language/effective-dart/design#avoid-positional-boolean-parameters
[prototype]: https://github.com/munificent/ui-as-code/tree/master/scripts/bin/parameter_binding.dart
[issue #4188]: https://github.com/dart-lang/sdk/issues/4188
[issue #6496]: https://github.com/dart-lang/sdk/issues/6496
[issue #7056]: https://github.com/dart-lang/sdk/issues/7056
[issue #16253]: https://github.com/dart-lang/sdk/issues/16253
[issue #21406]: https://github.com/dart-lang/sdk/issues/21406
[issue #33918]: https://github.com/dart-lang/sdk/issues/33918
[so 1]: https://stackoverflow.com/questions/13731631/creating-function-with-variable-number-of-arguments-or-parameters-in-dart
[so 2]: https://stackoverflow.com/questions/16262393/dart-how-to-make-a-function-that-can-accept-any-number-of-args/16266780
