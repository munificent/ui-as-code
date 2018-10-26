// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

final local = new Histogram<String>();
final field = new Histogram<String>();
final top = new Histogram<String>();
final statementExpr = new Histogram<String>();
final all = new Histogram<String>();
final modifier = new Histogram<String>();
final function = new Histogram<String>();
final strings = new Histogram<String>();
final blockFunction = new Histogram<String>();
final breaks = new Histogram<String>();
final continues = new Histogram<String>();

abstract class Interface {
  foo();
}

abstract class Supe implements Interface {}

class Sub extends Supe {}

/// Counts how many times a newline appears between various places in the
/// grammar.
void main(List<String> arguments) {
  parsePath(arguments[0], createVisitor: (path) => new VariableVisitor(path));

  local.printDescending("Local");
  field.printDescending("Field");
  top.printDescending("Top");
  all.printDescending("All");
  modifier.printDescending("Modifiers");
  statementExpr.printDescending("Statement expressions");
  function.printDescending("Local functions");
  strings.printDescending("Adjacent strings");
  blockFunction.printDescending("Block local functions");
  breaks.printDescending("Break labels");
  continues.printDescending("Continue labels");
}

class VariableVisitor extends Visitor {
  VariableVisitor(String path) : super(path);

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    for (var string in node.strings.skip(1)) {
      _check("strings", strings, string);
    }

    super.visitAdjacentStrings(node);
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    if (node.label != null) {
      _check("break label", breaks, node.label);
    } else {
      breaks.add("no label");
    }

    super.visitBreakStatement(node);
  }

  @override
  void visitContinueStatement(ContinueStatement node) {
    if (node.label != null) {
      _check("continue label", continues, node.label);
    } else {
      continues.add("no label");
    }

    super.visitContinueStatement(node);
  }

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    _checkVariables("local", local, node.variables);

    modifier.add(node.variables.keyword?.toString() ?? "none");

    super.visitVariableDeclarationStatement(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    _checkVariables("field", field, node.fields);

    super.visitFieldDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _checkVariables("top-level", top, node.variables);

    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    if (node.expression is SimpleIdentifier) {
      statementExpr.add("identifier");
    } else if (node.expression is PrefixedIdentifier) {
      statementExpr.add("prefixed");
    } else {
      statementExpr.add("other");
    }

    super.visitExpressionStatement(node);
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    if (node.functionDeclaration.returnType != null) {
      _check("function", function, node.functionDeclaration.name);
    } else {
      function.add("no return type");
    }

    var body = node.functionDeclaration.functionExpression.body;
    if (body is BlockFunctionBody) {
      _check("block body", blockFunction, body);
    } else if (body is ExpressionFunctionBody) {
      blockFunction.add("=> body");
    } else {
      blockFunction.add("unknown body");
    }

    super.visitFunctionDeclarationStatement(node);
  }

  void _checkVariables(
      String type, Histogram<String> histogram, VariableDeclarationList node) {
    _check(type, histogram, node.variables.first);
  }

  void _check(String type, Histogram<String> histogram, AstNode node) {
    _checkToken(type, histogram, node.beginToken);
  }

  void _checkToken(String type, Histogram<String> histogram, Token token) {
    var prevLine = getLine(token.previous.offset);
    var line = getLine(token.offset);

    if (prevLine != line) {
      histogram.add("on next line");
      all.add("$type on next line");
    } else {
      histogram.add("on same line");
      all.add("$type on same line");
    }
  }
}
