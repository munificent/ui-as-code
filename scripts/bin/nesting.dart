// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

/// Strings that describe the structure of each nested argument.
final nestings = new Histogram<String>();

/// The number of levels of nesting active when each argument appears.
final nestingDepths = new Histogram<int>();

/// The number of levels of nesting active when each argument appears.
final ignoringLists = new Histogram<int>();

/// The number of levels of "child" or "children" named parameter nesting when
/// each argument appears.
final childNestings = new Histogram<int>();

/// The names of each argument.
final argumentNames = new Histogram<String>();

bool simplifyNames = false;

void main(List<String> arguments) {
  arguments = arguments.toList();
  simplifyNames = arguments.remove("--simplify");
  var allCode = arguments.remove("--all");
  parsePath(arguments[0],
      createVisitor: (path) => new NestingVisitor(path, allCode: allCode));

  nestingDepths.printOrdered("Nesting depth");
  print("average = ${nestingDepths.sum / nestingDepths.totalCount}");
  ignoringLists.printOrdered("Ignoring lists");
  print("average = ${ignoringLists.sum / ignoringLists.totalCount}");
  childNestings.printOrdered("Child[ren] nesting depth");
  argumentNames.printDescending("Argument names");
  nestings.printDescending("Argument nesting");
}

class NestingVisitor extends Visitor {
  final List<String> _stack = [];

  final bool _allCode;
  bool _pushed = false;

  NestingVisitor(String path, {bool allCode})
      : _allCode = allCode ?? false,
        super(path);

  @override
  void visitArgumentList(ArgumentList node) {
    // Only argument lists with trailing commas get indentation.
    if (node.arguments.isNotEmpty &&
        node.arguments.last.endToken.next.type == TokenType.COMMA) {
      String name;
      var parent = node.parent;
      if (parent is MethodInvocation) {
        name = parent.methodName.name;
      } else if (parent is InstanceCreationExpression) {
        name = parent.constructorName.toString();
      } else if (parent is SuperConstructorInvocation) {
        name = "super.${parent.constructorName}";
      } else {
        name = "?(${parent.runtimeType})?";
      }

      if (simplifyNames) {
        name = "";
      }

      for (var argument in node.arguments) {
        var argName =
            argument is NamedExpression ? argument.name.label.name : "";

        if (_allCode || isInBuildMethod) argumentNames.add(argName);

        if (simplifyNames && argName != "child" && argName != "children") {
          argName = "_";
        }

        _push("$name($argName:");
        argument.accept(this);
        _pop();
      }
    } else {
      node.visitChildren(this);
    }
  }

  @override
  void visitBlock(Block node) {
    var isFunction = node.parent is BlockFunctionBody;
    if (!isFunction) _push("{");
    node.visitChildren(this);
    if (!isFunction) _pop();
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    _push("=>");
    node.visitChildren(this);
    _pop();
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    var isDeclaration = node.parent is FunctionDeclaration;
    if (!isDeclaration) _push("(){");
    node.visitChildren(this);
    if (!isDeclaration) _pop();
  }

  @override
  void visitListLiteral(ListLiteral node) {
    for (var element in node.elements) {
      _push("[");
      element.accept(this);
      _pop();
    }
  }

  @override
  void visitMapLiteral(MapLiteral node) {
    for (var entry in node.entries) {
      _push("{");
      entry.value.accept(this);
      _pop();
    }
  }

  void _push(String string) {
    _stack.add(string);
    _pushed = true;
  }

  void _pop() {
    if (_pushed && (_allCode || isInBuildMethod)) {
      nestings.add(_stack.join(" "));
      nestingDepths.add(_stack.length);
      ignoringLists.add(_stack.where((s) => s != "[").length);
      childNestings.add(_stack.where((s) => s.contains("child")).length);
    }
    _pushed = false;
    _stack.removeLast();
  }
}
