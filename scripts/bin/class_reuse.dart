// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/analyzer.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';
import 'package:ui_as_code_tools/visitor.dart';

final declarations = new Histogram<String>();
final uses = new Histogram<String>();
final superclasses = new Histogram<String>();
final superinterfaces = new Histogram<String>();
final mixins = new Histogram<String>();

void main(List<String> arguments) {
  parsePath(arguments[0],
      createVisitor: (path) => new ClassReuseVisitor(path));

  declarations.printDescending("Declarations");
  uses.printDescending("Uses");
  superclasses.printDescending("Superclass names");
  superinterfaces.printDescending("Superinterface names");
  mixins.printDescending("Mixin names");
}

class ClassReuseVisitor extends Visitor {
  ClassReuseVisitor(String path) : super(path);

  void visitClassDeclaration(ClassDeclaration node) {
    if (node.isAbstract) {
      declarations.add("abstract class");
    } else {
      declarations.add("class");
    }

    if (node.extendsClause != null) {
      uses.add("extend");
      superclasses.add(node.extendsClause.superclass.toString());
    }

    if (node.withClause != null) {
      for (var mixin in node.withClause.mixinTypes) {
        uses.add("mixin");
        mixins.add(mixin.toString());
      }
    }

    if (node.implementsClause != null) {
      for (var type in node.implementsClause.interfaces) {
        uses.add("implement");
        superinterfaces.add(type.toString());
      }
    }
  }
}
