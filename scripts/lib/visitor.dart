// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/source/line_info.dart';

/// Base Visitor class with some utility functionality.
class Visitor extends RecursiveAstVisitor<void> {
  final String path;

  int _inBuildMethods = 0;

  String _source;
  LineInfo _lineInfo;

  Visitor(this.path);

  bool get isInBuildMethod => _inBuildMethods > 0;

  bool _isBuildMethod(TypeAnnotation returnType, SimpleIdentifier name,
      FormalParameterList parameters) {
    var parameterString = parameters.toString();
    return returnType.toString() == "Widget" ||
        parameterString.startsWith("(BuildContext context") ||
        name.toString().contains("build");
  }

  void bind(String source, LineInfo info) {
    _source = source;
    _lineInfo = info;
  }

  void printNode(AstNode node) {
    var startLine = _lineInfo.getLocation(node.offset).lineNumber;
    var endLine = _lineInfo.getLocation(node.end).lineNumber;

    print("$path:$startLine");
    for (var line = startLine; line <= endLine; line++) {
      // Note that getLocation() returns 1-based lines, but getOffsetOfLine()
      // expects 0-based.
      var offset = _lineInfo.getOffsetOfLine(line - 1);
      // -1 to not include the newline.
      var end = _lineInfo.getOffsetOfLine(line) - 1;
      print("| ${_source.substring(offset, end)}");
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    var isBuild = _isBuildMethod(node.returnType, node.name, node.parameters);
    if (isBuild) _inBuildMethods++;

    super.visitMethodDeclaration(node);

    if (isBuild) _inBuildMethods--;
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    var isBuild = _isBuildMethod(
        node.returnType, node.name, node.functionExpression.parameters);
    if (isBuild) _inBuildMethods++;

    super.visitFunctionDeclaration(node);

    if (isBuild) _inBuildMethods--;
  }
}
