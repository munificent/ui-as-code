# Parameter Freedom

**TODO: Lots**

## Semantics

### Function subtyping

I'm ignoring generic type arguments because they aren't affected by this
proposal. To determine if function type `T` is a subtype of function type `S`:

1.  Let `required` be the number of required positional parameters in `S`.

    Let `positional` be the total number positional parameters in `S` &mdash;
    required, optional, and rest.

    It is valid to call `S` with anywhere from `required` to `positional`
    positional arguments (or more if there is a rest parameter, but we can
    ignore more than one of those).

    For each arity `arity` in that range:

    1.  Get the parameter list used for `T` at arity `arity` (see below).

    2.  Get the parameter list used for `S` at arity `arity`. If it does not
        have a valid one, `T` is not a subtype.

    3.  Otherwise, for each corresponding pair of parameters `pT` and `pS` in
        the parameter lists:

        1.  If `pS` is not a subtype of `pS`, `T` is not a subtype. This is the
            usual contravariant parameter subtype rule.

        2.  If `pT` is a rest parameter and `pS` is not, or vice versa, `T` is
            not a subtype.

2.  It the return type of `T` is not a subtype of the return type of `S`, `T`
    is not a subtype.

3.  **TODO: Do the normal named parameter checking here.**

4.  If we get here, `T` is a subtype.

#### Parameter list at arity

To generate the parameter list of a function type `T` at arity `arity`:

1.  Let `positional` be the total number positional parameters in `T` &mdash;
    required, optional, and rest.

    Let `required` be the number of required positional parameters in `T`.

    Let `optional` be the number optional parameters in `T`. (The rest parameter
    is not considered optional.)

    Let `hasRest` be true if `T` contains a rest parameter.

    Let `optionalArgs` be `arity - required`. This is the number of optional
    parameters that will be provided with arguments at this arity. (It may be
    larger than the total number of optional parameters, but that's OK.)

    Let `hasRestArgs` be true iff `arity - required - optionalArgs > 0`. This is
    true if there are enough arguments left over for the rest parameter.

2.  If `arity < required`, there are not enough arguments for this to be a valid
    call. `T` has no parameter list at this arity. Abort.

3.  If `optionalArgs > optional` and `hasRest` is false then there are too many
    arguments for this to be a valid call. `T` has no parameter list at this
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
