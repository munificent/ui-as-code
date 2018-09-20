- got couple of proposals in flight mostly around params
- todo: links
- helps flutter lot
  - can use mixed pos and named to turn "child" into positional
  - can use rest to turn "children" into rest
  - todo: examples

- biggest remaining problem is cond
  - expr always produces one val
  - to conditionally omit arg or args, means "expr" that may or may not eval
    to value

## three choices

- to address that, three different approaches can think of
- don't have detailed proposal (may not be able to), but very roughly sketch
  out
- fill in blanks yourself
- of course real proposal will fill in

- control flow elements
  - smallest proposal
  - in argument list or collection literal, allow "if"
    - optional "else"
    - not statements, special construct
    - todo: ex
    - when used in arg list body ("then", "else" or loop body) part is either
      argument (named or not) or parened sequence of args
    - in list, then part is expr or paren list of exprs
    - in map, it's key/value pair or parened list of key/val pairs
    - for list and map, natural to conditionally omit elements, since collection
      doesn't care
    - harder for arg
    - omitting named arg is fine, since named args don't affect each other
    - omitting positional shifts other positionals forward
    - interferes with static typing
    - to avoid, only allow syntax in arg list for passing rest args
  - also allow "for"
    - not strictly needed because of spread, but more natural for some things

  - pros
    - simplest
      - less to spec, implement, and test
      - less for users to learn
    - terse in simple cases
    - covers known use cases
      - in flutter code i see, almost all needs are simple
  - con
    - limited
      - can't do any statement, just couple of special ones
      - will users expect while? break? continue? try? catch?
    - uncanny
      - looks like familiar if statement, but behaves differently
      - then body is element, not statement

- argument block initializers
  - proposed by yegor
  - trailing block after ctor or fn
  - body is normal block: arbitrary statements, control flow, etc.
  - named args of thing being called in scope as locals
  - assigning to, passes arg
  - since full flow control, can omit arg by using normal if statement
  - todo: ex
  - pros
    - looks really nice
      - ruby, groovy, scala, kotlin, swift have similar syntax
    - reuses existing semantics
      - body is just a block with some pre-defined vars
      - everything else know about blocks applies
      - if works as normal
  - cons
    - not clear how to extend to positional params
      - one of key goals for ui as code
      - have list of children and want to omit some
      - that's either list literal or positional rest arg list
      - best idea so far is use "yield"
      - ex:
      - not declarative
      - more verbose for what is most common case

- markup
  - introduce some xml-ish notation
  - rouses strong feelings both ways
  - tag desugars to call to ctor or fn
  - attributes are named args
  - body is list of positional args
  - can interpolate expressions of dart code
  - (could maybe put named inside body too, lots of variations)
  - this is about all jsx supports
  - remember key goal conditional
  - also need to support control flow in there
  - so not just tree of tags any more
  - pros
    - some people just really like way it looks
    - in some ways, less punctuation heavy than other syntaxes
      - no separators between attributes or child tags
    - closing tags show name so may be easier to read
    - totally new grammar, gives more freedom to redefine syntax/semantics
      inside
  - cons
    - some hate
    - more verbose
    - adding support for cond means no longer strictly declarative or familiar
      - have to do some kind of if for attributes, so approaches weirdness and
        complexity of control flow elements
      - also need cond for positional child tags
      - allow statements in there? approaches complexity of block
    - aside from notation itself, which is strong pro for some people, doesn't
      seem to directly solve key problems

## holistic

- could weigh pros cons, pick
- but think much more important to evaluate not just feature itself, but impact
  on rest of language and experience
- couple of axes

  - prefer declarative
    - need to be able to imperate, but ui code is best when reading shows *what*
      ui is, not *how* built
    - when imperative and mutating, program *text* doesn't reflect ui
    - instead, have to mentally execute code to see how resulting ui is like

  - switching cost
    - have big nested expr using current syntax
      - need tiny amount of cond in it
      - how much work to integrate?

  - redundancy
    - two ways to express same thing
    - raises total cognitive load
    - user has to think and make choice
    - need guidelines for which to prefer when
    - if guidelines subtle or complex, can end up switching more often
      - raises switching cost

  - heterogeneity
    - if have multiple notations for function invocation / ctor, then possible
      to mix them in one expr
    - ex
    - think probably bad
    - reader has to mentally switch between sublanguages to read whole thing
    - has to have all sublangs in head
    - different pieces of expr that are semantically similar may look very
      different
    - want to minimize
    - implications
      - one notation needs to good enough for all use cases
        - if blocks are much worse than arg lists for some cases, can't
          expect user to use blocks for everything
        - etc. markup
      - raises redundancy
        - notation needs to cover everything others can do so that user
          can use one homogenously across most uses
      - switching cost goes up
        - if user needs to use different notation for part of expr, pressure
          to migrate entire expr to same notation to keep homogeneous

  - garden path feature
    - some features encourage users to adopt entire mental model
    - if feature doesn't support entire model, expectations thwarted
    - leads them down dead end in garden path
    - for ex, dart has const exprs
    - const expr subset of language
    - subset feels arbitrary
    - users keep expecting larger region of expr grammar to work in const
      context: const sets, substrings, etc.
    - want feature to feel "complete"

  - future-proofing
    - any proposal claims syntactic territory for own use
    - future selves can't use for other feature
    - for example, could use "?" today for optional parameter instead of []
    - but really good chance add non-nullable types to lang and would be very
      sad if couldn't use "?" for that
    - too much worry about this paralyzing
    - do have to ship features today, so have to claim things

- think these concerns (except maybe future proof) more important than pros
  cons of individual feature

## revisiting

- revisit three branches in light

- control flow elements
  - prefer declarative
    - expr actually surprisingly declarative
    - [1, 2, 3] is what list is
    - using .add() to build (like in old java or c#) much more imperative
    - so if prefer decl, suggests prefer expr
    - works well
    - `if ()` here isn't as much like control flow as it is like data flow
    - then body is implicitly declarative expr
    - doesn't have to yield or assign, just is
  - switching cost
    - excellent
    - given existing arg list, if want to omit one, just put if right there
    - no other changes
    - if don't need any more, remove if and back to vanilla arg list
  - redundancy
    - also excellent
    - doesn't add entirely new syntax for invocation
    - doesn't do anything you can already do without lot of effort
    - [some overlap with "?:" but that's always been somewhat redundant]
  - heterogeneity
    - great, only one syntax
    - feature applies at level of invidual arg
  - garden path feature
    - real concerns here
    - only gives two control flow forms, only in certain places
    - will users want while? break?
      - to some degree, think limitation could be good thing
      - if start doing *lot* of imperative stuff: local vars, break, etc.
      - code is no longer declarative
      - maybe *should* hoist it out of middle of ui tree to separate fn
    - will want to use `if` as expr outside of arg lists?
  - future-proofing
    - not bad
    - minor incremental addition to grammar
    - restricted in where it applies
    - not like adding new expr or statement form

- argument initializer block
  - prefer declarative
    - bad
    - body of block is explicitly imperative
    - passing named args is assignment expr, not too bad
    - need some way to handle positional args
    - "yield" is explicitly imperative and verbose
    - ex: common case example
  - switching cost
    - really concerning
    - imagine long arg list
    - need to make one cond
    - have to turn parens to braces
    - turn every ":" to "="
    - every "," to ";"
    - remember to add trailing
    - can do quick fix, but still lot of change
  - redundancy
    - also really concerning
    - entirely separate notation for invocation
    - for common case where just have list of positional args, block notation
      is lot worse with "yield" everywhere
    - hard to beat (a, b) at own game
    - even for named arg case, not really better
    - little more verbose with space before "="
    - unlike with ",", looks very weird to pack onto one line
    - basically only better if actually need "if"
    - gets too
  - heterogeneity
    - looks pretty bad if mix block and normal arg syntax
    - mishmash of parens, braces, colons, equals, and semicolons
    - if use dartfmt without trailing comma, inconsistent formatting
    - because block syntax notably worse in many common cases, likely to run
      into hetero often
  - garden path feature
    - scores really well
    - block is normal block, can do everything in it
    - feels complete
  - future-proofing
    - does concern me
    - syntax is really nice
    - not convinced using it for right semantics
    - some other langs use for passing lambda to fn
    - would be great to use that for dart: group(), test(), event handler
    - others use it for "builder" stuff where body is executed with implicit
      "this" that api can control
    - really powerful for *imperative* dsl-like apis
    - flutter use case is declarative
    - feels like a better fit for statement-based block syntax

- markup
  - prefer declarative
    - for simple cases, scores really well
    - syntax is very familiar and sends strong "data" or "declarative" signal
      to many
    - child tags as positional args nice and declarative
    - once actually need cond stuff, though, gets weirder
    - depends on how we actually do cond
    - could be ok, maybe not
  - switching cost
    - *really* bad
    - notation is radically different from invocation
    - angle brackets, closing tag (including name)
    - need to reorganize args so that named args are first as attributes
    - currently always last in dart
    - can interfere with eval order
    - may require escaping or paren when inserting dart expr inside
  - redundancy
    - also bad
    - like block, is entire new notation for invoke
    - in addition to new tag syntax, also need to define cond syntax inside it
    - jsx and xml don't have
    - so both redundant syntax and unfamiliar syntax
  - heterogeneity
    - assuming like markup syntax, not too bad
    - pretty declarative, so works ok even for cases that are ok in old syntax
    - more verbose, though so tiny cases look weird
    - `<Text>"some string"</Text>`
    - using tag inside attribute looks strange because xml doesn't allow
  - garden path feature
    - so-so
    - common part of xml pretty small and do support most of syntax
    - have to decide what body of tag is
    - if full block with arb statements, have problem like blocks where have to
      explicitly yield
    - if not, then can be garden path if only some subset of statements allowed
  - future-proofing
    - probably fine
    - carves out entire new region of grammar
    - semantics are probably what would want xml notation to mean
    - desugars to invocation of arbitrary user api, so not tied to any specific
      dom api (like scala and e4x) or library (like jsx for react)

## conclusion

- can't always do good design by analyzing numbers, but to summarize

```
                    control elements  block               markup
prefer declarative  good              bad                 maybe
switching cost      excellent         really concerning   really bad
redundancy          excellent         really concerning   bad
heterogeneity       great             pretty bad          not too bad
garden path         concerning        really good         so-so
future-proofing     not bad           concerns            fine
```

- really surprised
- personally really attached to block or markup
- on fence about which
- more think about it, more feel neither harmonizes with whole user experience
- control elem small, limited feature
- but feels right-sized for problem
- not silver bullet
- want some feedback, user studies
- but think best branch to try first
