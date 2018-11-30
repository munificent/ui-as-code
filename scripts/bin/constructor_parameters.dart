// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

/// Looks at constructor declarations to see how many of them take one or more
/// list-typed parameters. This should help us gauge how important it is to
/// support more than one var-arg parameter.
final listParamCounts = new Histogram<int>();
final listTypePattern = new RegExp(r"\b(Iterable|List)\b");

final widgetParamCounts = new Histogram<int>();

void main(List<String> arguments) {
  parsePath(arguments[0],
      createVisitor: (path) => new ConstructorVisitor(path));

  print("${listParamCounts.totalCount} classes");
  for (var i = 0; i < 5; i++) {
    var count = listParamCounts.count(i);
    var percent =
        (100.0 * count / listParamCounts.totalCount).toStringAsFixed(2);
    print("${count} ($percent%) constructors take $i sequence parameters");
  }

  for (var i = 0; i < 5; i++) {
    var count = widgetParamCounts.count(i);
    var percent =
        (100.0 * count / widgetParamCounts.totalCount).toStringAsFixed(2);
    print("${count} ($percent%) constructors take $i Widget parameters");
  }
}

class ConstructorVisitor extends Visitor {
  bool showedPath = false;

  ConstructorVisitor(String path) : super(path);

  void show(
      ClassDeclaration node, ConstructorDeclaration ctor, List<String> params) {
    if (!showedPath) {
      print(path);
      showedPath = true;
    }

    if (ctor.name == null) {
      print("  ${node.name.name}(");
    } else {
      print("  ${node.name.name}.${ctor.name.name}(");
    }

    for (var param in params) {
      print("    $param");
    }
    print("  )");
  }

  void showTerse(
      String label, ClassDeclaration node, ConstructorDeclaration ctor, List<String> params) {
    var buffer = StringBuffer();

    buffer.write("$label: ");
    if (ctor.name == null) {
      buffer.write("${node.name.name}(");
    } else {
      buffer.write("${node.name.name}.${ctor.name.name}(");
    }

    buffer.writeAll(params, ", ");
    buffer.write(") // $path");
    print(buffer);
  }

  void visitClassDeclaration(ClassDeclaration node) {
    TypeAnnotation findFieldType(String name) {
      for (var member in node.members) {
        if (member is FieldDeclaration) {
          for (var field in member.fields.variables) {
            if (field.name.name == name) return member.fields.type;
          }
        }
      }

      // Couldn't find a type. Just ignore it.
      return null;
    }

    for (var member in node.members) {
      if (member is ConstructorDeclaration) {
        var params = <String>[];
        var listCount = 0;
        var widgetCount = 0;
        var hasChild = false;
        var hasChildren = false;

        checkParam(SimpleIdentifier name, TypeAnnotation type) {
          type ??= findFieldType(name.name);
          if (type.toString().contains("List<")) listCount++;
          if (type.toString() == "Widget") widgetCount++;
          if (name.name == "child") hasChild = true;
          if (name.name == "children") hasChildren = true;
          params.add("${name.name}: $type");
        }

        for (var param in member.parameters.parameters) {
          var actualParam =
              (param is DefaultFormalParameter) ? param.parameter : param;

          if (actualParam is FieldFormalParameter) {
            checkParam(actualParam.identifier, actualParam.type);
          } else if (actualParam is SimpleFormalParameter) {
            checkParam(actualParam.identifier, actualParam.type);
          } else if (actualParam is FunctionTypedFormalParameter) {
            // Can ignore functions.
          } else {
            // Unexpected type.
            throw actualParam;
          }
        }

        listParamCounts.add(listCount);
        widgetParamCounts.add(widgetCount);
//        if (listCount > 1 || widgetCount > 1) show(node, member, params);
        if (hasChildren) {
          showTerse("children", node, member, params);
        }
        if (hasChild) {
          showTerse("child", node, member, params);
        }
      }
    }
    return null;
  }
}
