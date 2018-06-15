Widget build(BuildContext context) {
  IconButton button;
  if (isWindows) {
    button = IconButton(
      icon: Icon(Icons.menu),
      tooltip: 'Navigation menu',
    );
  } else {
    button = IconButton(
      icon: Icon(Icons.menu),
      tooltip: 'Navigation menu',
      padding: const EdgeInsets.all(20.0),
    );
  }

  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    child: Row(
      children: [
        button,
        Expanded(
          child: title,
        ),
        IconButton(
          icon: Icon(Icons.search),
          tooltip: 'Search',
        ),
      ],
    ),
  );
}