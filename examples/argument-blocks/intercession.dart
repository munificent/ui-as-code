Widget build(BuildContext context) {
  // Note: can't use "var" here :-(
  Widget result = Container {
    color = Colors.blue;
  };

  if (!isWednesday) {
    result = DecoratedBox {
      color = Colors.green;
      child = result;
    };
  }

  return Container {
    color = Colors.red;
    child = result;
  };
}

// Using a helper function:
Widget _buildBox() {
  var blueBox = Container {
    color = Colors.blue;
  };

  if (isWednesday) return blueBox;

  return DecoratedBox {
    color = Colors.green;
    child = blueBox;
  };
}

Widget build(BuildContext context) {
  return Container {
    color = Colors.red;
    child = _buildBox();
  };
}

// Using a general-purpose function:

Widget conditional(
        bool shouldWrap, Widget Function(Widget) wrapCallback, Widget widget) =>
    shouldWrap ? wrapCallback(widget) : widget;

Widget build(BuildContext context) {
  result = Container {
    color = Colors.red;
    child = conditional(
      !isWednesday,
      (widget) => DecoratedBox {
            color = Colors.green;
            child = widget;
          },
      Container {
        color = Colors.blue;
      },
    },
  };

  return result;
}
