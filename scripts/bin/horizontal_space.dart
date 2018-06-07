import 'dart:io';
import 'dart:math' as math;

/// Looks at the aggregate line length statistics inside and outside of build()
/// methods. Usage:
///
///     dart bin/horizontal_space.dart [--ignore-paren-lines] <dir>
///
/// if "--ignore-paren-lines" is passed, lines containing only ")", "),", or
/// ");" are not counted.
final buildHist = new Histogram();
final otherHist = new Histogram();

bool ignoreParenLines;

void main(List<String> arguments) {
  arguments = arguments.toList();
  ignoreParenLines = arguments.remove("--ignore-paren-lines");

  for (var entry in new Directory(arguments[0]).listSync(recursive: true)) {
    if (!entry.path.endsWith(".dart")) continue;

    measureFile(entry as File);
  }

  var buildTotal = buildHist.totalCount;
  var otherTotal = otherHist.totalCount;
  for (var i = 1; i < 100; i++) {
    var buildPercent = (100 * buildHist.count(i) / buildTotal).toStringAsFixed(2).padLeft(5);
    var b = (200 * buildHist.count(i) / buildTotal).toInt();
    var bar = "*" * b + " " * (50 - b);

    var o = (200 * otherHist.count(i) / otherTotal).toInt();
    var other = "*" * o + " " * (50 - o);

    var otherPercent = (100 * otherHist.count(i) / otherTotal).toStringAsFixed(2).padLeft(5);
    print("${i.toString().padLeft(2)}: ${buildPercent}% $bar ${otherPercent}% $other");
  }

  print("build total = $buildTotal, average = ${buildHist.sum / buildTotal}, median = ${buildHist.median}");
  print("other total = $otherTotal, average = ${otherHist.sum / otherTotal}, median = ${otherHist.median}");
}

void measureFile(File file) {
  print(file.path);
  var nesting = 0;
  for (var line in file.readAsLinesSync()) {
    // Optional "new"!
    line = line.replaceAll("new ", "");

    var trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith("//")) continue;

    if (ignoreParenLines) {
      if (trimmed == "),") continue;
      if (trimmed == ");") continue;
      if (trimmed == ")") continue;
    }

    if (trimmed == "Widget build(BuildContext context) {") {
      nesting = 1;
    }

    if (nesting > 0) {
//      print(">>> $line");
      buildHist.add(trimmed.length);
    } else {
//      print("    $line");
      otherHist.add(trimmed.length);
    }

    if (nesting > 0) {
      if (trimmed == "{") {
        nesting++;
      } else if (trimmed == "}") {
        nesting--;
      }
    }
  }
}

class Histogram {
  final Map<int, int> _counts = {};

  int get max => _counts.values.fold(0, math.max);
  int get totalCount => _counts.values.fold(0, (a, b) => a + b);

  int get sum {
    var result = 0;
    _counts.forEach((value, count) {
      result += value * count;
    });
    return result;
  }

  int get median {
    // TODO: Super hacky.
    var list = <int>[];
    _counts.forEach((value, count) {
      for (var i = 0; i < count; i++) list.add(value);
    });
    list.sort();
    return list[list.length ~/ 2];
  }

  int add(int object) {
    _counts.putIfAbsent(object, () => 0);
    return ++_counts[object];
  }

  int count(int object) {
    if (!_counts.containsKey(object)) return 0;
    return _counts[object];
  }
}