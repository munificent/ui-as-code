Widget build(BuildContext context) {
  return <Scaffold
    body=<Container> // TODO: Make positional?
      <ListView>
        <Column>
          <RadioListTile
            title=const Text('Value')
            onChanged(value) {
              setState(() {
                selectedLogEnumValue = value;
              });
            }
          />
        </Column>
      </ListView>
    </Container>
  />;
}
