Widget build(BuildContext context) {
  return CupertinoTabScaffold(
    tabBuilder: (BuildContext context, int index) {
      return CupertinoTabView(
        builder: (BuildContext context) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('Page 1 of tab $index'),
            ),
            child: Center(
              child: CupertinoButton(
                child: const Text('Next page'),
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<Null>(
                      builder: (BuildContext context) {
                        return CupertinoPageScaffold(
                          navigationBar: CupertinoNavigationBar(
                            middle: Text('Page 2 of tab $index'),
                          ),
                          child: Center(
                            child: CupertinoButton(
                              child: const Text('Back'),
                              onPressed: () { Navigator.of(context).pop(); },
                            ), // Center
                          ), // CupertinoPageScaffold
                        );
                      },
                    ), // CupertinoPageRoute
                  ); // push
                },
              ), // CupertinoButton
            ), // Center
          ); // CupertinoPageScaffold
        },
      ); // CupertinoTabView
    },
  ); // CupertinoTabScaffold
}