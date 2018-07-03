@override
Widget build(BuildContext context) {
  return new _ModalScopeStatus(
    route: widget.route,
    isCurrent: widget.route.isCurrent, // _routeSetState is called if this updates
    canPop: widget.route.canPop, // _routeSetState is called if this updates
    child: new Offstage(
      offstage: widget.route.offstage, // _routeSetState is called if this updates
      child: new PageStorage(
        bucket: widget.route._storageBucket, // immutable
        child: new FocusScope(
          node: widget.route.focusScopeNode, // immutable
          child: new RepaintBoundary(
            child: new AnimatedBuilder(
              animation: _listenable, // immutable
              builder: (BuildContext context, Widget child) {
                return widget.route.buildTransitions(
                  context,
                  widget.route.animation,
                  widget.route.secondaryAnimation,
                  new IgnorePointer(
                    ignoring: widget.route.animation?.status == AnimationStatus.reverse,
                    child: child,
                  ),
                );
              },
              child: _page ??= new RepaintBoundary(
                key: widget.route._subtreeKey, // immutable
                child: new Builder(
                  builder: (BuildContext context) {
                    return widget.route.buildPage(
                      context,
                      widget.route.animation,
                      widget.route.secondaryAnimation,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
