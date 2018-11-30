// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';

import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

void main(List<String> arguments) {
  parsePath(arguments[0], createVisitor: (path) => new DefaultValueVisitor(path));
}

class DefaultValueVisitor extends Visitor {
  DefaultValueVisitor(String path) : super(path);

  final Set<FormalParameterList> _shown = Set();

  bool _hasControlFlow = false;

  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) {
    super.visitDefaultFormalParameter(node);

//    if (node.defaultValue != null) {
//      if (_shown.add(node.parent)) {
//        printNode(node.parent);
//      }
//    }
  }

  void beforeVisitBuildMethod(Declaration node) {
    _hasControlFlow = false;
  }

  void afterVisitBuildMethod(Declaration node) {
    if (_hasControlFlow) printNode(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    super.visitConditionalExpression(node);

//    _hasControlFlow = true;
  }

  @override
  void visitIfStatement(IfStatement node) {
    super.visitIfStatement(node);

    _hasControlFlow = true;
  }
}
