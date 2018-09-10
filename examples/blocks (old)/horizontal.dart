Widget build(BuildContext context) {
  return Card {
    color = Colors.white
    child = Center {
      child = Column {
        yield Icon(choice.icon, size: 128.0, color: textStyle.color)
        yield Text(choice.title, style: textStyle)
      }
    }
  }
}
