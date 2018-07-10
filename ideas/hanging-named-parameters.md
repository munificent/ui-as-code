This is possibly a terrible idea, but here goes. Much of the pain of the current
syntax comes from gratuitous indentation. This has two main causes:

- A chain of nested "child" Widgets.
- A list literal of "children" Widgets nested inside an argument list.

Ruby's block arguments let you place a trailing block outside of the
parentheses. We could take that one step farther and allow any named argument to
hang after the closing `)`.

So this:

```dart
PopupMenuItem<String> _buildMenuItem(IconData icon, String label) {
  return PopupMenuItem(
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: Icon(icon, color: Colors.black54)
        ),
        Text(label, style: menuItemStyle),
      ],
    ),
  );
}
```

Becomes:

```dart
PopupMenuItem<String> _buildMenuItem(IconData icon, String label) {
  return PopupMenuItem<String>()
    child: Row() children: [
      Padding(
        padding: const EdgeInsets.only(right: 24.0),
        child: Icon(icon, color: Colors.black54)
      ),
      Text(label, style: menuItemStyle),
    ];
}
```

It looks really weird. I've tried it on a number of samples and have yet to find
a consistent, good way to format it. But I believe it might actually parse and
it's at least semantically simple.

But, really, it's weird.
