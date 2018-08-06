Compared to the "original" directory, this contains only a few minor language
changes:

*   **Allow mixing positional and named arguments.** Dart currently requires all
    positional arguments to appear before all named ones. This relaxes that and
    lets them appear in any order.

    Then I take advantage of that by making any parameter named `child` into
    a positional parameter and removing the name.

*   **Varargs.** A member can accept a variable-length sequence of arguments of
    the same type. In the examples here, I found few cases where this needed to
    be mixed with other positional or named arguments in the same expression,
    but I don't think supporting that is hard.

    In some cases, you want to pass a series of arguments to something expecting
    a vararg but the arguments are already packed into a list. To enable that,
    I also define a prefix `...` "spread" operator.

    Then I take advantage of that by turning any parameter named `children`
    into a positional vararg parameter.

I think these two language changes are pretty "safe" in that:

*   Many other languages support the same thing.
*   We've discussed them both heavily before.
*   They don't introduce novel, unusual syntax. With the minor exception of
    `...`, the only visible difference at a callsite is that you may see a
    named argument follow a positional one.

In return, though, my impression is that the improvement is not large. Getting
rid of `child` helps. Losing `children` and the extra indentation from the list
literal is nice. (It may be worth doing user studies to see if my impression is
justified.)

But the painful structural problems around conditionally including arguments
are still there, and there is still quite a lot of punctuation and indentation
from nested widgets.
