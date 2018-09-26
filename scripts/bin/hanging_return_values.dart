// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/source/line_info.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';

var files = 0;
var lines = 0;
final counts = new Histogram<String>();

void main(List<String> arguments) {
  forEachDartFile(arguments[0], (file, relative) {
    // Skip the SDK tests. There are a bunch that have magic comments right
    // before certain tokens to validate error messages and those end up
    // pushing the return to the next line. This isn't normal Dart code.
    if (relative.startsWith("sdk/tests/")) return;
    files++;

    parseFile(file, relative, (path, lineInfo) {
      lines += lineInfo.lineCount;
      return new Visitor(path, lineInfo);
    });
  });

  counts.printDescending("Results", showAll: true);
  print("Files: $files");
  print("Lines: $lines");
}

class Visitor extends RecursiveAstVisitor<void> {
  final String path;
  final LineInfo lineInfo;
  bool showedPath = false;

  Visitor(this.path, this.lineInfo);

  void show(ReturnStatement node) {
    if (!showedPath) {
      print(path);
      showedPath = true;
    }

    print(node);
  }

  void visitReturnStatement(ReturnStatement node) {
    if (node.expression == null) {
      counts.add("No value");
    } else if (lineInfo.getLocation(node.returnKeyword.offset).lineNumber !=
        lineInfo.getLocation(node.returnKeyword.next.offset).lineNumber) {
      show(node);
      counts.add("Hanging");
    } else {
      counts.add("Same line");
    }
  }
}
