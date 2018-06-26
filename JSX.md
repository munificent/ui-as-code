[React](https://reactjs.org/) uses
[JSX](https://reactjs.org/docs/introducing-jsx.html), an HTML-like DSL that
Babel compiles to React constructor calls. This is a quick evaluation to see
what we can learn from it for "UI as Code" in Dart.

## Summary

JSX is a thin syntactic sugar over the React API. Tags are compiled by Babel
directly to calls to `React.createElement()`. You can tweak Babel to compile it
to calls to your own function if you want to use the syntax but not be tied to
React.

JSX is the de facto way of authoring components in React. Most React users use
it. The typical reason for not using it is not wanting to set up a build system
to compile your JS, which isn't a relevant concern for us.

Most of the criticism centers around the limitations of only being able to embed
JS expressions inside the JSX, and not full statements. In particular, the lack
of conditional inclusion and loops.

### Pros

* Closing tags make it easier to read a long list of end delimiters.
* Syntax is familiar to people who know HTML or XML.
* Easy to embed text inline without needing to quote or escape strings.
* No separators needed between properties or child tags.
* Syntactic distinction between properties and child elements.
* Can use `{...object}` to interpolate a number of properties.

### Cons

* No conditional tags.
* No looping or other control flow.
* Aside from simple interpolated expressions, very hard to introduce imperative
  code.
* Have to decide whether to make something a property or child element.

## What People Are Saying

*   [The Good and Bad Parts of JSX](https://medium.com/@roman01la/the-good-and-bad-parts-of-jsx-33d01ea5c21f)

    *   "JSX is a de facto standard for declaring components structure in React
        applications."

    *   "I personally started using JSX because it's less verbose than plain
        JavaScript…"

    *   "JSX seems to be a good choice, and it works well until you try to
        compose it with plain JavaScript. It simply doesn't compose, because
        JavaScript has statements and JSX is based on expressions."

    *   Regarding the lack of control flow: "This doesn't change the fact that
        we are doomed to keep adding more syntax into JSX as we need it."

*   [JSX is no longer my friend](https://medium.com/@jador/jsx-4b978fbeb290)

    *   "I have had a lot of success with React, building several apps and
        training nearly a dozen developers to use it. This is thanks, in part,
        to JSX."

    *   "JSX involves a fair amount of contextual switching"

    *   Regarding lack of control flow: "JSX is pretty noisy with its tags and
        curly braces. Since hyperscript is just JavaScript we can make use of
        some of the conveniences of JavaScript to clean things up."

    *   "My team has been using hyperscript in the real world for nearly a month
        now. So far everyone on the team is enjoying the experience and there
        are far fewer gaffes like described before."

    *   [Hacker News comments on it](https://news.ycombinator.com/item?id=11290827)

*   [More Than React: Why You Shouldn't Use ReactJS for Complex Interactive Front-End Projects, Part I](https://www.infoq.com/articles/more-than-react-part-i)

    Ignoring the non-JSX parts of the article…

    *   "However, React's support for HTML is incomplete. Developers have to
        manually replace class and for attributes with classname and htmlFor."

    *   "For example, if you spelled onclick instead of onClick, React would
        report no errors and the program would crash as well." [Shouldn't be
        relevant for us.]

*   [How I learned to stop worrying and love the JSX](http://jamesknelson.com/learned-stop-worrying-love-jsx/)

## Relevant To Flutter

*   [Flutter issue #15922](https://github.com/flutter/flutter/issues/15922):
    Consider JSX-like as React Native

    *   👍 39, 👎 37, 😕 6, 106 comments

*   [Flutter issue #11609](https://github.com/flutter/flutter/issues/11609):
    Consider JSX-like syntax inside dart code

    *   👍 70, 👎 42, ❤️ 4, 160 comments

    *   [Interesting comment](https://github.com/flutter/flutter/issues/11609#issuecomment-323223496)

    *   [Ian]](https://github.com/flutter/flutter/issues/11609#issuecomment-3238
        50 722): "One thing we've found in Flutter is that big build methods are
        not great for performance, and we try to encourage people to break down
        their build methods into smaller reusable widgets. In particular, in
        Flutter having a build method that's built out of the results of other
        methods is somewhat of an antipattern that we'd rather discourage rather
        than make easier."

*   [DSX](https://spark-heroku-dsx.herokuapp.com/index.html), a prototype
    transpiler of JSX-like syntax in Dart.

*   [edaloicaro18](https://github.com/flutter/flutter/issues/11609#issuecomment-
    385588741): "The only thing that is stopping me from giving Flutter a try is
    the fact that they chose not to use JSX. IMHO JSX is the best choice to
    express component hierarchy."

    👍 12, 👎 6, 🎉 3, ❤️ 4
