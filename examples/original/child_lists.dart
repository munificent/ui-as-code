Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      child: ListView(
        children: [
          Column(
            children: [
              RadioListTile(
                title: const Text('Value'),
                onChanged: (value) {
                  setState(() {
                    selectedLogEnumValue = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}