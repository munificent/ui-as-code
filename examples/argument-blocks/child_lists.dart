Widget build(BuildContext context) {
  return Scaffold {
    body = Container {
      child = ListView(
        Column(
          RadioListTile {
            title = const Text('Value');
            onChanged = (value) {
              setState(() {
                selectedLogEnumValue = value;
              });
            };
          },
        ),
      );
    };
  };
}