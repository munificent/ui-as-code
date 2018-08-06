Widget build(BuildContext context) {
  return Card(
    color: Colors.white,
    Center(
      Column(
        Icon(
          choice.icon,
          size: 128.0,
          color: textStyle.color,
        ),
        Text(
          choice.title,
          style: textStyle,
        ),
      ),
    ),
  );
}