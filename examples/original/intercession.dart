Widget build(BuildContext context) {
  // Note: can't use "var" here :-(
  Widget result = Container(
    color: Colors.blue,
  );

  if (!isWednesday) {
    result = DecoratedBox(
      color: Colors.green,
      child: result,
    );
  }

  result = Container(
    color: Colors.red,
    child: result,
  );

  return result;
}