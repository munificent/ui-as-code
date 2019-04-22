// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

/// Expressions used to convert a null-aware expression to a Boolean for use in
/// a Boolean context.
var booleanConversions = Histogram<String>();

/// Boolean contexts where null-aware operators are used.
var booleanContexts = Histogram<String>();

var nullAwareTypes = Histogram<String>();
var nullAwareLengths = Histogram<String>();

void main(List<String> arguments) {
  parsePath(arguments[0], createVisitor: (path) => NullVisitor(path));

  nullAwareTypes.printDescending("Null-aware types");
  nullAwareLengths.printDescending("Null-aware chain lengths");
  booleanContexts.printDescending("Boolean contexts");
  booleanConversions.printDescending("Boolean conversions");
}

var identifier = RegExp("[a-zA-Z_][a-zA-Z_0-9]*");

class NullVisitor extends Visitor {
  NullVisitor(String path) : super(path);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.operator != null &&
        node.operator.type == TokenType.QUESTION_PERIOD) {
      _nullAware(node);
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.operator.type == TokenType.QUESTION_PERIOD) {
      _nullAware(node);
    }

    super.visitPropertyAccess(node);
  }

  void _nullAware(AstNode node) {
    var parent = node.parent;

    // Parentheses are purely syntactic.
    if (parent is ParenthesizedExpression) parent = parent.parent;

    // We want to treat a chain of null-aware operators as a single unit. We
    // use the top-most node (the last method in the chain) as the "real" one
    // because its parent is the context where the whole chain appears.
    if (parent is PropertyAccess &&
            parent.operator.type == TokenType.QUESTION_PERIOD &&
            parent.target == node ||
        parent is MethodInvocation &&
            parent.operator != null &&
            parent.operator.type == TokenType.QUESTION_PERIOD &&
            parent.target == node) {
      // This node is not the root of a null-aware chain, so skip it.
      return;
    }

    // This node is the root of a null-aware chain. See how long the chain is.
    var length = 0;
    var chain = node;
    while (true) {
      if (chain is PropertyAccess &&
          chain.operator.type == TokenType.QUESTION_PERIOD) {
        chain = (chain as PropertyAccess).target;
      } else if (chain is MethodInvocation &&
          chain.operator != null &&
          chain.operator.type == TokenType.QUESTION_PERIOD) {
        chain = (chain as MethodInvocation).target;
      } else {
        break;
      }

      length++;
    }

    nullAwareLengths.add(length.toString());

    record(String label) {
      nullAwareTypes.add("$label");
    }

    // See if the expression is an if condition.
    _checkCondition(node);

    if (parent is ExpressionStatement) {
      record("Expression statement 'foo?.bar();'");
      return;
    }

    if (parent is ReturnStatement) {
      record("Return statement 'return foo?.bar();'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.BANG_EQ &&
        parent.leftOperand == node &&
        parent.rightOperand is BooleanLiteral &&
        (parent.rightOperand as BooleanLiteral).value == true) {
      record("Compare to true 'foo?.bar() != true'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.EQ_EQ &&
        parent.leftOperand == node &&
        parent.rightOperand is BooleanLiteral &&
        (parent.rightOperand as BooleanLiteral).value == true) {
      record("Compare to true 'foo?.bar() == true'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.BANG_EQ &&
        parent.leftOperand == node &&
        parent.rightOperand is BooleanLiteral &&
        (parent.rightOperand as BooleanLiteral).value == false) {
      record("Compare to false 'foo?.bar() != false'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.EQ_EQ &&
        parent.leftOperand == node &&
        parent.rightOperand is BooleanLiteral &&
        (parent.rightOperand as BooleanLiteral).value == false) {
      record("Compare to false 'foo?.bar() == false'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.BANG_EQ &&
        parent.leftOperand == node &&
        parent.rightOperand is NullLiteral) {
      record("Compare to null 'foo?.bar() != null'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.EQ_EQ &&
        parent.leftOperand == node &&
        parent.rightOperand is NullLiteral) {
      record("Compare to null 'foo?.bar() == null'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.EQ_EQ) {
      record("Compare to other expression 'foo?.bar() == bang'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.BANG_EQ) {
      record("Compare to other expression 'foo?.bar() != bang'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.QUESTION_QUESTION &&
        parent.leftOperand == node) {
      record("Coalesce 'foo?.bar() ?? baz'");
      return;
    }

    if (parent is BinaryExpression &&
        parent.operator.type == TokenType.QUESTION_QUESTION &&
        parent.rightOperand == node) {
      record("Reverse coalesce 'baz ?? foo?.bar()'");
      return;
    }

    if (parent is ConditionalExpression && parent.condition == node) {
      record("Condition in conditional expression 'foo?.bar() ? baz : bang");
      return;
    }

    if (parent is ConditionalExpression) {
      record("Then or else branch of conditional 'baz ? foo?.bar() : bang");
      return;
    }

    if (parent is AsExpression && parent.expression == node) {
      record("Cast expression 'foo?.bar as Baz'");
      return;
    }

    if (parent is AssignmentExpression && parent.leftHandSide == node) {
      record("Assign target 'foo?.bar ${parent.operator} baz'");
      return;
    }

    if (parent is AssignmentExpression && parent.rightHandSide == node) {
      record("Assign value 'baz = foo?.bar()'");
      return;
    }

    if (parent is VariableDeclaration && parent.initializer == node) {
      record("Variable initializer 'var baz = foo?.bar();'");
      return;
    }

    if (parent is NamedExpression) {
      record("Named argument 'fn(name: foo?.bar())'");
      return;
    }

    if (parent is ArgumentList && parent.arguments.contains(node)) {
      record("Positional argument 'fn(foo?.bar())'");
      return;
    }

    if (parent is AwaitExpression) {
      record("Await 'await foo?.bar()'");
      return;
    }

    if (parent is MapLiteralEntry || parent is ListLiteral) {
      record("Collection literal element '[foo?.bar()]'");
      return;
    }

    if (parent is ExpressionFunctionBody) {
      record("Member body 'member() => foo?.bar();'");
      return;
    }

    if (parent is InterpolationExpression) {
      record("String interpolation '\"blah \${foo?.bar()}\"'");
      return;
    }

    if (parent is BinaryExpression) {
      record("Uncategorized ${parent}");
      return;
    }

    record("Uncategorized ${parent.runtimeType}");

    // Find the surrounding statement containing the null-aware.
    while (node is Expression) {
      node = node.parent;
    }

    printNode(node);
  }

  void _checkCondition(Expression node) {
    String expression;

    // Look at the expression that immediately wraps the null-aware to see if
    // it deals with it somehow, like "foo?.bar ?? otherwise".
    var parent = node.parent;
    if (parent is ParenthesizedExpression) parent = parent.parent;

    if (parent is BinaryExpression &&
        (parent.operator.type == TokenType.EQ_EQ ||
            parent.operator.type == TokenType.BANG_EQ ||
            parent.operator.type == TokenType.QUESTION_QUESTION) &&
        (parent.rightOperand is NullLiteral ||
            parent.rightOperand is BooleanLiteral)) {
      var binary = parent as BinaryExpression;
      expression = "foo?.bar ${binary.operator} ${binary.rightOperand}";

      // This does handle it, so see the context where it appears.
      node = parent;
      if (node is ParenthesizedExpression) node = node.parent;
      parent = node.parent;
      if (parent is ParenthesizedExpression) parent = parent.parent;
    }

    String context;
    if (parent is IfStatement && node == parent.condition) {
      context = "if";
    } else if (parent is BinaryExpression && parent.operator.type == TokenType.AMPERSAND_AMPERSAND) {
      context = "&&";
    } else if (parent is BinaryExpression && parent.operator.type == TokenType.BAR_BAR) {
      context = "||";
    } else if (parent is WhileStatement && node == parent.condition) {
      context = "while";
    } else if (parent is DoStatement && node == parent.condition) {
      context = "do";
    } else if (parent is ForStatement && node == parent.condition) {
      context = "for";
    } else if (parent is ConditionalExpression && node == parent.condition) {
      context = "?:";
    }

    if (context != null) {
      booleanContexts.add(context);

      if (expression != null) {
        booleanConversions.add(expression);
      } else {
        booleanConversions.add("unknown: $node");
      }
    }
  }
}
