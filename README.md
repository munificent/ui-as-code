This repo tracks design work to try to extend Dart syntax to better support
Flutter's style of UI code and similar code in other frameworks.

Usual caveats apply: the work is early, experimental, and subject to change. It
might not pan out at all.

## Docs

*   [Motivation][] - A detailed breakdown of the current usability problems that
    we're trying to improve.

*   [Constraints][] - Softer guiding principles to help get as much value as we
    can from a solution.

*   [Research][] - Background information on other languages and frameworks and
    how they approach this. Prior art, inspiration, and pitfalls to avoid.
    [JSX][] gets its own page.

*   [Choices][] - High level survey of different approaches to handling
    conditional execution.

## Proposals

*   [Parameter Freedom][] - Loosen restrictions around positional, optional, and
    named parameters. Add rest parameters and a spread operator. Let API authors
    define flexible, expressive parameter lists that free callers from writing
    useless boilerplate.

*   [Spread Collections][] - Allow the same `...` spread syntax from [Parameter
    Freedom][] to be used in list and map literals to insert multiple elements.

[motivation]: https://github.com/munificent/ui-as-code/blob/master/Motivation.md
[constraints]: https://github.com/munificent/ui-as-code/blob/master/Constraints.md
[research]: https://github.com/munificent/ui-as-code/blob/master/Research.md
[jsx]: https://github.com/munificent/ui-as-code/blob/master/JSX.md
[choices]: https://github.com/munificent/ui-as-code/blob/master/Choices.md
[parameter freedom]: https://github.com/munificent/ui-as-code/blob/master/in-progress/parameter-freedom.md
[spread collections]: https://github.com/munificent/ui-as-code/blob/master/in-progress/spread-collections.md
