// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:ui_as_code_tools/histogram.dart';

/// Looks at the aggregate line length statistics inside and outside of build()
/// methods. Usage:
///
///     dart bin/horizontal_space.dart [--ignore-paren-lines] <dir>
///
/// if "--ignore-paren-lines" is passed, lines containing only ")", "),", or
/// ");" are not counted.
final buildHist = new Histogram<int>();
final otherHist = new Histogram<int>();

/// Detects functions that build widgets. Best effort only. Does not capture all functions.
final RegExp buildFunctionSignature = new RegExp(r"Widget _?\w+\(BuildContext.*\) \{");

/// The number of functions we detected using [buildFunctionSignature].
int buildFunctionCount = 0;

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
    var b = 200 * buildHist.count(i) ~/ buildTotal;
    var bar = "*" * b + " " * (50 - b);

    var o = 200 * otherHist.count(i) ~/ otherTotal;
    var other = "*" * o + " " * (50 - o);

    var otherPercent = (100 * otherHist.count(i) / otherTotal).toStringAsFixed(2).padLeft(5);
    print("${i.toString().padLeft(2)}: ${buildPercent}% $bar ${otherPercent}% $other");
  }

  print("detected ${buildFunctionCount} widget building functions");
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

    if (trimmed.contains(buildFunctionSignature)) {
      buildFunctionCount++;
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
