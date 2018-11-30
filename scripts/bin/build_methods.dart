// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

final constructors = new Histogram<String>();
final signatures = new Histogram<String>();
final invocations = new Histogram<String>();

/// The paths to each build() method and its length in lines.
final buildMethods = <String, int>{};

void main(List<String> arguments) {
  parsePath(arguments[0], createVisitor: (path) => new BuildVisitor(path));

  constructors.printDescending("Constructors");
  signatures.printDescending("Signatures");
  invocations.printDescending("Invocations");

  var methods = buildMethods.keys.toList();
  methods.sort((a, b) => buildMethods[b].compareTo(buildMethods[a]));
  for (var method in methods) {
    print("${buildMethods[method].toString().padLeft(3)}: $method");
  }
  print("${buildMethods.length} build() methods");
}

class BuildVisitor extends Visitor {
  BuildVisitor(String path) : super(path);

  Declaration _builder;

  @override
  void beforeVisitBuildMethod(Declaration node) {
    _builder = node;
  }

  @override
  void afterVisitBuildMethod(Declaration node) {
    var startLine = lineInfo.getLocation(node.offset).lineNumber;
    var endLine = lineInfo.getLocation(node.end).lineNumber;

    buildMethods["$path:$startLine"] = endLine - startLine;

//    printNode(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    node.visitChildren(this);

    if (!isInBuildMethod) return;

    if (node.methodName.name == "map") {
      printNode(_builder);
    }

//    String name;
//    if (node.target == null) {
//      name = node.methodName.name;
//    } else if (node.target is SimpleIdentifier) {
//      name = "${node.target}.${node.methodName}";
//    } else {
//      // Instance method call.
//      return;
//    }
//
//    if (name.codeUnitAt(0) >= 65 && name.codeUnitAt(0) <= 90) {
//      var signature = node.argumentList.arguments.map((arg) {
//        if (arg is NamedExpression) return "${arg.name.label.name}";
//        return "_";
//      }).toList();
//      signature.sort();
//
//      constructors.add(name);
//      signatures.add("$name(${signature.join(',')})");
//      invocations.add(node.toString());
//    }
  }
}
