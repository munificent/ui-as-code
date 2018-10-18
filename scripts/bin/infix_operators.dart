// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

final minus = new Histogram<String>();
final lessThan = new Histogram<String>();
final paren = new Histogram<String>();
final bracket = new Histogram<String>();

/// Counts how many times an empty statement as used as the body of various
/// control flow statements.
void main(List<String> arguments) {
  parsePath(arguments[0], createVisitor: (path) => new OperatorVisitor(path));

  minus.printDescending("Minus", showAll: true);
  lessThan.printDescending("Less than", showAll: true);
  paren.printDescending("Paren", showAll: true);
  bracket.printDescending("Bracket", showAll: true);
}

class OperatorVisitor extends Visitor {
  final _context = ["decl"];

  OperatorVisitor(String path) : super(path);

  @override
  void visitBlock(Block node) {
    _context.add("stmt");
    super.visitBlock(node);
    _context.removeLast();
  }

  @override
  void visitListLiteral(ListLiteral node) {
    _context.add("expr");
    super.visitListLiteral(node);
    _context.removeLast();
  }

  @override
  void visitMapLiteral(MapLiteral node) {
    _context.add("expr");
    super.visitMapLiteral(node);
    _context.removeLast();
  }

  @override
  void visitAssertStatement(AssertStatement node) {
    _context.add("expr");
    super.visitAssertStatement(node);
    _context.removeLast();
  }

  @override
  void visitArgumentList(ArgumentList node) {
    _check("(", node.leftParenthesis, paren);

    _context.add("expr");
    super.visitArgumentList(node);
    _context.removeLast();
  }

  @override
  void visitForStatement(ForStatement node) {
    _context.add("expr");
    node.variables?.accept(this);
    node.initialization?.accept(this);
    node.condition?.accept(this);
    node.updaters?.accept(this);
    _context.removeLast();

    node.body.accept(this);
  }

  @override
  void visitForEachStatement(ForEachStatement node) {
    _context.add("expr");
    node.iterable.accept(this);
    _context.removeLast();

    node.body.accept(this);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    _context.add("expr");
    super.visitFormalParameterList(node);
    _context.removeLast();
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    _check("[", node.leftBracket, bracket);

    _context.add("expr");
    super.visitIndexExpression(node);
    _context.removeLast();
  }

  @override
  void visitParenthesizedExpression(ParenthesizedExpression node) {
    _context.add("expr");
    super.visitParenthesizedExpression(node);
    _context.removeLast();
  }

  @override
  void visitIfStatement(IfStatement node) {
    _context.add("expr");
    node.condition.accept(this);
    _context.removeLast();

    node.thenStatement.accept(this);
    node.elseStatement?.accept(this);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _context.add("expr");
    node.condition.accept(this);
    _context.removeLast();

    node.body.accept(this);
  }

  @override
  void visitDoStatement(DoStatement node) {
    node.body.accept(this);

    _context.add("expr");
    node.condition.accept(this);
    _context.removeLast();
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    _context.add("expr");
    node.expression.accept(this);
    _context.removeLast();

    node.statements.accept(this);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _check("-", node.operator, minus);
    _check("<", node.operator, lessThan);

    super.visitBinaryExpression(node);
  }

  void _check(String operator, Token token, Histogram<String> histogram) {
    if (token.lexeme == operator) {
      var prevLine = getLine(token.previous.offset);
      var line = getLine(token.offset);

      var context = _context.last == "expr"
          ? "in expression context"
          : "not in expression context";
      if (prevLine != line) {
        histogram.add("infix $operator at beginning of line $context");
      } else {
        histogram.add("infix $operator on same line $context");
      }
    }
  }

  void temp() {
    var a;

    a - a;
    (a - a);
    a
    - a;
    (a
        - a);

    a < a;
    (a < a);
    a
    < a;
    (a
        < a);

    a[a];
    (a[a]);
    a
      [a];
    (a
        [a]);

    a(a);
    (a(a));
    a
      (a);
    (a
        (a));
  }
}
