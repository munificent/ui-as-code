// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

/// Known cases where an "if" statement could instead be an "if" element inside
/// a list or map literal. Usually this is an optional child widget in a list
/// of children.
final _knownCollection =
    ["flutter/examples/layers/widgets/styled_text.dart"].toSet();

final _buildMethods = <String>[];
final _histogram = Histogram<String>();

void main(List<String> arguments) {
  parsePath(arguments[0],
      createVisitor: (path) => new ControlFlowVisitor(path));

  _buildMethods.shuffle();
  for (var i = 0; i < 100; i++) {
    print(_buildMethods[i]);
  }

  _histogram.printDescending("build methods");
}

class ControlFlowVisitor extends Visitor {
  ControlFlowVisitor(String path) : super(path);

  final List<String> _controlFlow = [];

  void beforeVisitBuildMethod(Declaration node) {
    _controlFlow.clear();
  }

  void afterVisitBuildMethod(Declaration node) {
    if (_controlFlow.isNotEmpty) {
      _buildMethods.add(nodeToString(node));

      var hasIf = _controlFlow.any((s) => s.startsWith("if"));
      var hasConditional = _controlFlow.any((s) => s.startsWith("conditional"));

      if (hasIf && hasConditional) {
        _histogram.add("both");
      } else if (hasIf) {
        _histogram.add("if");
      } else {
        _histogram.add("conditional");
      }
    } else {
      _histogram.add("no control flow");
    }
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    super.visitConditionalExpression(node);

    if (!isInBuildMethod) return;

    if (node.parent is NamedExpression) {
      _controlFlow.add("conditional named arg");
    } else if (node.parent is ArgumentList) {
      _controlFlow.add("conditional positional arg");
    } else if (node.parent is VariableDeclaration) {
      _controlFlow.add("conditional variable");
    } else if (node.parent is InterpolationExpression) {
      _controlFlow.add("conditional interpolation");
    } else {
      _controlFlow.add("conditional");
    }
  }

  @override
  void visitIfStatement(IfStatement node) {
    super.visitIfStatement(node);

    if (!isInBuildMethod) return;

    if (_isReturn(node.thenStatement) && _isReturn(node.elseStatement)) {
      _controlFlow.add("if return");
    } else if (_isAdd(node.thenStatement) && _isAdd(node.elseStatement)) {
      _controlFlow.add("if add");
    } else if (_knownCollection.contains(path)) {
      _controlFlow.add("if collection");
    } else {
      _controlFlow.add("if");
    }
  }

  bool _isReturn(Statement statement) {
    // Ignore empty "else" clauses.
    if (statement == null) return true;

    if (statement is ReturnStatement) return true;

    if (statement is Block &&
        statement.statements.length == 1) {
      return _isReturn(statement.statements.first);
    }

    return false;
  }

  bool _isAdd(Statement statement) {
    // Ignore empty "else" clauses.
    if (statement == null) return true;

    if (statement is ExpressionStatement) {
      var expr = statement.expression;
      if (expr is MethodInvocation) {
        if (expr.methodName.name == "add" || expr.methodName.name == "addAll") {
          return true;
        }
      }
    } else if (statement is Block && statement.statements.length == 1) {
      return _isAdd(statement.statements.first);
    }

    return false;
  }
}
