// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:path/path.dart' as p;

import 'package:ui_as_code_tools/histogram.dart';

/// Looks at constructors to see how many of them take one or more list-typed
/// parameters. This should help us gauge how important it is to support more
/// than one var-arg parameter.
final listParamCounts = new Histogram<int>();
final listTypePattern = new RegExp(r"\b(Iterable|List)\b");

final widgetParamCounts = new Histogram<int>();

void main(List<String> arguments) {
  var directory = arguments[0];
  for (var entry in new Directory(directory).listSync(recursive: true)) {
    if (!entry.path.endsWith(".dart")) continue;

    // Don't care about tests.
    if (entry.path.contains("/test/")) continue;

    // Don't care about cached packages.
    if (entry.path.contains("/.dart_tool/")) continue;

    processFile(entry as File, p.relative(entry.path, from: directory));
  }

  print("${listParamCounts.totalCount} classes");
  for (var i = 0; i < 5; i++) {
    var count = listParamCounts.count(i);
    var percent = (100.0 * count / listParamCounts.totalCount).toStringAsFixed(2);
    print("${count} ($percent%) constructors take $i sequence parameters");
  }

  for (var i = 0; i < 5; i++) {
    var count = widgetParamCounts.count(i);
    var percent = (100.0 * count / widgetParamCounts.totalCount).toStringAsFixed(2);
    print("${count} ($percent%) constructors take $i Widget parameters");
  }
}

void processFile(File file, String path) {
  var source = file.readAsStringSync();

  var errorListener = new ErrorListener();

  // Tokenize the source.
  var reader = new CharSequenceReader(source);
  var stringSource = new StringSource(source, file.path);
  var scanner = new Scanner(stringSource, reader, errorListener);
  var startToken = scanner.tokenize();

  // Parse it.
  var parser = new Parser(stringSource, errorListener);
  parser.enableOptionalNewAndConst = true;

  var node = parser.parseCompilationUnit(startToken);

  // Format it.
  var visitor = new Visitor(path);
  node.accept(visitor);
}

/// A simple [AnalysisErrorListener] that just collects the reported errors.
class ErrorListener implements AnalysisErrorListener {
  void onError(AnalysisError error) {
    print(error);
  }
}

class Visitor extends RecursiveAstVisitor<void> {
  final String path;
  bool showedPath = false;

  Visitor(this.path);

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

        checkParam(SimpleIdentifier name, TypeAnnotation type) {
          type ??= findFieldType(name.name);
          if (type.toString().contains("List<")) listCount++;
          if (type.toString() == "Widget") widgetCount++;
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
        if (listCount > 1 || widgetCount > 1) show(node, member, params);
      }
    }
    return null;
  }
}
