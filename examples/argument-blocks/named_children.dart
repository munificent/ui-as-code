Widget build(BuildContext context) {
  return ListTile {
    leading = const Icon(Icons.flight_land);
    title = const Text('Trix\'s airplane');
    if (_act != 2) {
      subtitle = const Text('The airplane is only in Act II.');
    }
    enabled = _act == 2;
    onTap = () {
      /* react to the tile being tapped */
    };
  };
}