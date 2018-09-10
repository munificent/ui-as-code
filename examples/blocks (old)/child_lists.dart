Widget build(BuildContext context) {
  return Scaffold {
    body = Container {
      yield ListView {
        yield Column {
          yield RadioListTile {
            title = const Text('Value')
            onChanged = (value) {
              setState(() {
                selectedLogEnumValue = value;
              })
            }
          }
        }
      }
    }
  }
}