// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';

/// Strings that describe the structure of each nested argument.
final nestings = new Histogram<String>();

/// The number of levels of nesting active when each argument appears.
final nestingDepths = new Histogram<int>();

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
  parseDirectory(arguments[0], (path) => new Visitor(path, allCode: allCode));

  nestingDepths.printOrdered("Nesting depth");
  childNestings.printOrdered("Child[ren] nesting depth");
  argumentNames.printDescending("Argument names");
  nestings.printDescending("Argument nesting");
}

class Visitor extends RecursiveAstVisitor<void> {
  final String path;
  bool showedPath = false;

  final List<String> _stack = [];

  bool _pushed = false;
  int _inBuildMethods = 0;

  Visitor(this.path, {bool allCode}) {
    if (allCode) _inBuildMethods++;
  }

  bool _isBuildMethod(TypeAnnotation returnType, SimpleIdentifier name,
      FormalParameterList parameters) {
    var parameterString = parameters.toString();
    return returnType.toString() == "Widget" ||
        parameterString.startsWith("(BuildContext context") ||
        name.toString().contains("build");
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

        if (_inBuildMethods > 0) argumentNames.add(argName);

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

//  @override
//  R visitFunctionDeclaration(FunctionDeclaration node) {
//    node.visitChildren(this);
//    return null;
//  }
//
//  @override
//  R visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
//    node.visitChildren(this);
//    return null;
//  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    var isDeclaration = node.parent is FunctionDeclaration;
    if (!isDeclaration) _push("(){");
    node.visitChildren(this);
    if (!isDeclaration) _pop();
  }

  @override
  void visitListLiteral(ListLiteral node) {
    // Only lists with trailing commas get indentation.
    if (node.elements.isNotEmpty &&
        node.elements.last.endToken.next.type == TokenType.COMMA) {
      for (var element in node.elements) {
        _push("[");
        element.accept(this);
        _pop();
      }
    } else {
      node.visitChildren(this);
    }
  }

  @override
  void visitMapLiteral(MapLiteral node) {
    // Only maps with trailing commas get indentation.
    if (node.entries.isNotEmpty &&
        node.entries.last.endToken.next.type == TokenType.COMMA) {
      for (var entry in node.entries) {
        _push("{");
        entry.value.accept(this);
        _pop();
      }
    } else {
      node.visitChildren(this);
    }
  }

  void _push(String string) {
    _stack.add(string);
    _pushed = true;
  }

  void _pop() {
    if (_pushed && _inBuildMethods > 0) {
//      print(_stack.join(" "));
      nestings.add(_stack.join(" "));
      nestingDepths.add(_stack.length);
      childNestings.add(_stack.where((s) => s.contains("child")).length);
    }
    _pushed = false;
    _stack.removeLast();
  }
}
