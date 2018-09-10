Widget build(BuildContext context) {
  return <Container
    height=56.0
    padding=const EdgeInsets.symmetric(horizontal: 8.0)
    decoration=BoxDecoration(color: Colors.blue[500])
  >
    <Row>
      <IconButton
        icon=Icon(Icons.menu)
        tooltip='Navigation menu'
        if (!isWindows) padding=const EdgeInsets.all(20.0)
      />
      <Expanded child=title />
      if (!isAndroid) {
        <IconButton icon=Icon(Icons.search) tooltip='Search' />
      }
    </Row>
  </Container>;
}
