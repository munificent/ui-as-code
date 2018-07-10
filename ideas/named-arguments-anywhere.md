Leaving a note of this here because it's relevant to UI as code.

One of the small features we've discussed for a long time that will likely help
UI code is to allow positional arguments to appear after named arguments.

This would let `child` and `children` be positional arguments, turning this:

```dart
Container(
  width: 100.0,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        child: Text(
          "Text1",
          style: TextStyle(color: Colors.black),
        ),
      ),
      Container(
        child: Text(
          "Text2",
          style: TextStyle(color: Colors.black),
        ),
      )
    ],
  ),
)
```

into:

```dart
Container(
  width: 100.0,
  Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    [
      Container(
        Text(
          style: TextStyle(color: Colors.black),
          "Text1",
        ),
      ),
      Container(
        Text(
          style: TextStyle(color: Colors.black),
          "Text2",
        ),
      )
    ],
  ),
)
```

Tracking bugs: [#15398](https://github.com/dart-lang/sdk/issues/15398) [#30353](https://github.com/dart-lang/sdk/issues/30353)
