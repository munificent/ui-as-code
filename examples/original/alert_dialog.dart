Future<Null> _neverSatisfied() async {
  return showDialog<Null>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (context) {
      return AlertDialog(
        title: Text("Rewind and remember"),
        content: SingleChildScrollView(
          ListBody(
            children: [
              Text("You will never be satisfied."),
              Text("You're like me. I'm never satisfied."),
            ],
          ),
        ),
        actions: [
          FlatButton(
            Text("Regret"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
