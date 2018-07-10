// If you have a series of nested tags, could support collapsing them to avoid
// wasted indentation and closing tags:

If we do an XML-ish markup notation, you still have the issue of lots of deep
nested chains of single widgets. One oddball idea is to allow collapsing a
series of them:

So this:

```dart
<Container>
  <ListView>
    <Column>
      <RadioListTile>
        title = const Text('Value');
        onChanged = (value) {
          setState(() {
            selectedLogEnumValue = value;
          });
        };
      </RadioListTile>
    </Column>
  </ListView>
</Container>
```

becomes something like:

```dart
<Container/ListView/Column/RadioListTile>
  title = const Text('Value');
  onChanged = (value) {
    setState(() {
      selectedLogEnumValue = value;
    });
  };
</>
```

This has (at least) two issues with it:

- We have to figure out what to do for the closing tag. Here I used the old SGML
  syntax, but that might not be something we want.

- In practice, many of these outer widgets take another parameter or two in
  addition to a child widget. Cramming extra argumens into this would likely be
  really ugly.

My hunch is this is a non-starter, but recording it here for posterity or to
possibly inspire a better feature.

