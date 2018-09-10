Here's an idea: In HTML, you have to decide what goes in attributes and what in
child tags. Usually the heuristic is around "small" stuff or metadata being in
attributes.

Let's solve this mechanically: named arguments are attributes, positional are
child tags. Now we don't need to figure out how to put positional args in
attributes or named args in child tags.

* Can have callback attributes without using "=":

    <Tag callback() {...} />

* Spread to expand list of child tags.

* Can use `if (condition)` before attribute name to conditionally include.

* Likewise, `if (condition)` in child tag body. With braces.

* Can use `for` inside tag body. (See chat_message.dart.)

TODO: How do you conditionally omit an attribute?

TODO: What expressions are allowed inside tags? deep_chain.dart is doing
`_page ??= ...`.
