// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

var files = 0;
var lines = 0;
final counts = new Histogram<String>();

void main(List<String> arguments) {
  parsePath(arguments[0],
      createVisitor: (path) => new HangingReturnVisitor(path));

  counts.printDescending("Results", showAll: true);
  print("Files: $files");
  print("Lines: $lines");
}

class HangingReturnVisitor extends Visitor {
  bool showedPath = false;

  HangingReturnVisitor(String path) : super(path) {
    files++;
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    node.visitChildren(this);
    lines += lineInfo.lineCount;
  }

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
