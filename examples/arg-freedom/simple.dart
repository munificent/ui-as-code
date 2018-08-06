Widget build(BuildContext context) {
  return Container(
    height: 56.0,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(color: Colors.blue[500]),
    Row(
      IconButton(
        icon: Icon(Icons.menu),
        tooltip: 'Navigation menu',
      ),
      Expanded(
        title,
      ),
      IconButton(
        icon: Icon(Icons.search),
        tooltip: 'Search',
      ),
    ),
  );
}