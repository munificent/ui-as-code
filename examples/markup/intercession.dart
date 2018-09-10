Widget build(BuildContext context) {
  // Note: can't use "var" here :-(
  Widget result = <Container color=Colors.blue />;

  if (!isWednesday) {
    result = <DecoratedBox color=Colors.green>result</DecoratedBox>;
  }

  return <Container color=Colors.red>result</Container>;
}

// Using a helper function:
Widget _buildBox() {
  var blueBox = <Container color=Colors.blue />;

  if (isWednesday) return blueBox;

  return <DecoratedBox color=Colors.green>blueBox</DecoratedBox>;
}

Widget build(BuildContext context) {
  return <Container color=Colors.red>_buildBox()</Container>;
}

// Using a general-purpose function:

Widget conditional(
        bool shouldWrap, Widget Function(Widget) wrapCallback, Widget widget) =>
    shouldWrap ? wrapCallback(widget) : widget;

Widget build(BuildContext context) {
  result = <Container color=Colors.red>
    conditional(
      !isWednesday,
      (widget) => <DecoratedBox color=Colors.green>widget</DecoratedBox>,
      <Container color=Colors.blue />,
    )
  </Container>;

  return result;
}
