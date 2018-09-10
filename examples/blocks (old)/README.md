*   **Allow mixing positional and named arguments.** Dart currently requires all
    positional arguments to appear before all named ones. This relaxes that and
    lets them appear in any order.

    Then I take advantage of that by making any parameter named `child` into
    a positional parameter and removing the name.

*   **Rest parameters.** A member can accept a variable-length sequence of
    arguments of the same type. In the examples here, I found few cases where
    this needed to be mixed with other positional or named arguments in the same
    expression, but I don't think supporting that is hard.

    In some cases, you want to pass a series of arguments to something expecting
    a vararg but the arguments are already packed into a list. To enable that,
    I also define a prefix `...` "spread" operator.

    Then I take advantage of that by turning any parameter named `children`
    into a positional vararg parameter.

*   **Argument initializer blocks.** Instead of a parenthesized argument list
    **(TODO: Allow both?)**, a braced argument initializer block can be
    provided. The body of that is a block containing arbitrary statements. It's
    executed in a namespace where the named parameters of the called method are
    in scope as locals. Assigning to them is equivalent to passing the value as
    an argument.

    If the caller accepts a rest parameter, `yield` and `yield*` can be used in
    the body to add to the rest object.

*   **Optional semicolons.** The main reason is that assigning a function to
    a named argument in an initializer block is very error-prone if the
    semicolon is required afterwards.

*   **Don't use trailing commas in regular argument lists.** Instead, use the
    "classic" dartfmt indentation style. If you want block-like nesting, use an
    argument initializer block.

<!-- TODO: is child turned positional or not? needs to be named to use in
block arg.

But it seems pointless even there. See "child_lists.dart".

The mandatory "yields" in child_lists.dart for the single children of Column
and ListView are kind of gross. I'm really worried that forgetting to yield
will be a common problem. It's hard to lint for since a constructor technically
can have a side-effect. :(

delimiters.dart has a nasty corner case where a function that expects a single
positional argument is passing a big nested widget. We need to use the old
syntax for the outer call, but then it contains the new syntax inside. :(

Not supporting positional parameters in an initializer block seems to conflict
with the rule that you shouldn't have an initializer block nested inside an old
style argument list.

Overall, this looks OK, but not great to me. It's not as bad as I feared. But
the "yield" and not supporting positional args are friction points. Also, the
"child =" everywhere is super nasty.

Some kind of decorator syntax would help. But positional args would too. It may
be that the key problem is that an initializer block assumes you want imperative
code and you have to opt into declarative by either doing an assignment or a
yield. That's probably the wrong default.

-->
