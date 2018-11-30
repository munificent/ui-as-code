// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

var argHist = Histogram<String>();
var paramHist = Histogram<String>();

var argListLines = Histogram<String>();
var lines = 0;

void main(List<String> arguments) {
  parsePath(arguments[0],
      createVisitor: (path) => new TrailingCommaVisitor(path));

  argHist.printDescending("Arguments");
  paramHist.printDescending("Parameters");
  argListLines.printDescending("Argument lines");
  print("$lines total lines");
}

class TrailingCommaVisitor extends Visitor {
  TrailingCommaVisitor(String path) : super(path);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    node.visitChildren(this);
    lines += lineInfo.lineCount;
  }

  @override
  void visitArgumentList(ArgumentList node) {
    var startLine = getLine(node.leftParenthesis.offset);
    var endLine = getLine(node.rightParenthesis.offset);
    if (startLine == endLine) {
      argListLines.add("same line");
    } else {
      argListLines.add("different lines");
    }

    if (node.arguments.isEmpty) {
      argHist.add("empty");
    } else if (node.rightParenthesis.previous.toString() == ",") {
      if (path.startsWith("flutter")) {
        argHist.add("flutter trailing comma");
      } else {
        argHist.add("non-flutter trailing comma");
      }
    } else {
      argHist.add("non-trailing");
    }

    super.visitArgumentList(node);
  }

  @override
  void visitFormalParameterList(FormalParameterList node, [arg,]) {
    if (node.parameters.isEmpty) {
      paramHist.add("empty");
    } else if (node.rightParenthesis.previous.toString() == "," ||
        node.rightParenthesis.previous.previous.toString() == ",") {
      if (path.startsWith("flutter")) {
        paramHist.add("flutter trailing comma");
      } else {
        paramHist.add("non-flutter trailing comma");
      }
    } else {
      paramHist.add("non-trailing");
    }

    super.visitFormalParameterList(node);
  }
}
