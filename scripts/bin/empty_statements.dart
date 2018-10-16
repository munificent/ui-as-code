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
final all = new Histogram<String>();

/// Counts how many times an empty statement as used as the body of various
/// control flow statements.
void main(List<String> arguments) {
  parsePath(arguments[0],
      createVisitor: (path) => new EmptyStatementVisitor(path));

  counts.printDescending("By type", showAll: true);
  all.printDescending("All", showAll: true);
  print("Files: $files");
  print("Lines: $lines");
}

class EmptyStatementVisitor extends Visitor {
  EmptyStatementVisitor(String path) : super(path) {
    files++;
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    node.visitChildren(this);
    lines += lineInfo.lineCount;
  }

  // TODO(rnystrom): Is there anything we need to do for switch?

  void check(String label, Statement body) {
    if (body is EmptyStatement) {
      counts.add("$label empty");
      all.add("empty");

      var line = lineInfo.getLocation(body.offset).lineNumber;
      print("$path:$line : $label");
    } else {
      counts.add(label);
      all.add("non-empty");
    }
  }

  void visitDoStatement(DoStatement node) {
    check("do-while", node.body);
  }

  void visitForEachStatement(ForEachStatement node) {
    check(node.awaitKeyword != null ? "await-for" : "for-in", node.body);
  }

  void visitForStatement(ForStatement node) {
    check("for", node.body);
  }

  void visitIfStatement(IfStatement node) {
    check("if-then", node.thenStatement);
    check("if-else", node.elseStatement);
  }

  void visitWhileStatement(WhileStatement node) {
    check("while", node.body);
  }
}
