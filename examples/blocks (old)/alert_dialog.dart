Future<Null> _neverSatisfied() async {
  return showDialog<Null> {
    context = context
    barrierDismissible = false // user must tap button!
    builder = (context) {
      return AlertDialog {
        title = Text("Rewind and remember")
        content = SingleChildScrollView {
          child = ListBody {
            yield Text("You will never be satisfied.")
            yield Text("You're like me. I'm never satisfied.")
          }
        }
        actions = [
          FlatButton {
            child = Text("Regret")
            onPressed = () {
              Navigator.of(context).pop()
            }
          }
        ]
      }
    }
  }
}
