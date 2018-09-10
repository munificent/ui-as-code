These examples show what Flutter code could look like based on:

*   Supporting all of the language changes in the [Parameter Freedom][]
    proposal.

*   Turning any parameter named `children` in the Flutter API into a rest
    parameter.

*   This does *not* turn parameters named `child` into positional parameters.
    Since the simple named argument block proposal does not support positional
    parameters inside the block, this would prevent using the block syntax on
    widgets with children.

*   Using spread arguments where applicable.

*   Support the language changes in the [Named Argument Blocks] idea.

*   Extend argument blocks to allow `yield` and `yield*` to provide rest
    arguments.

[parameter freedom]: https://github.com/munificent/ui-as-code/blob/master/in-progress/parameter-freedom.md
[named argument blocks]: https://github.com/munificent/ui-as-code/blob/master/ideas/named-argument-blocks.md
