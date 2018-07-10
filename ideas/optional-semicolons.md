A real proposal for this obviously needs detailed rules for which newlines are
ignored and which are significant. But this is just a bookmark to note that
semicolons could be made optional and newlines treated as semicolons in obvious
places.

Here's an example:

```dart
Widget build(BuildContext context) {
  IconButton button
  if (isWindows) {
    button = IconButton(icon: Icon(Icons.menu), tooltip: 'Navigation menu')
  } else {
    button = IconButton(
      icon: Icon(Icons.menu),
      tooltip: 'Navigation menu',
      padding: const EdgeInsets.all(20.0),
    )
  }

  List<Widget> buttons = [button, Expanded(child: title)]

  if (!isAndroid) {
    buttons.add(IconButton(icon: Icon(Icons.search), tooltip: 'Search'))
  }

  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    child: Row(children: buttons),
  )
}
```

This removes some noisy punctuation, and makes it easier to move code between
expression contexts (no semicolons) and statement contexts (semicolons). If we
can figure out a notation that gets rid of the commas separating a series of
arguments of child widgets, optional semicolons makes that transition even
smoother.

Optional semicolons also fix the common pitfall where assigning a lambda needs a
trailing semicolon while declaring a function does not:

```dart
main() {
  callback = () {
    ...
  } // <-- Error. Forgot ";".
}; // <-- Error. Should not have ";".
```

Languages that do this include JavaScript, Lua, Go, Scala, Ruby, Python, Kotlin,
Swift, Groovy, Haskell, CoffeeScript, etc.

JavaScript's rules for "semicolon insertion" are inane and are not to be
followed. Other languages have their own rules that differ across language but
broadly seem to work out without too much trouble.
