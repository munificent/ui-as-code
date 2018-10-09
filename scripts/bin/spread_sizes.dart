// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:math' as math;

import 'package:analyzer/analyzer.dart';

import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';

/// Looks at expressions that could likely be converted to spread operators and
/// measures their length. "Likely" means calls to `addAll()` where the
/// receiver is a list or map literal.
final argumentStrings = Histogram<String>();
final argumentLengths = Histogram<int>();

void main(List<String> arguments) {
  parsePath(arguments[0], createVisitor: (path) => new Visitor(path));

  argumentStrings.printDescending("Arguments");
  _showLengths("Lengths");
}

void _showLengths(String label) {
  int min, max;
  for (var key in argumentLengths.objects) {
    min = math.min(min ?? key, key);
    max = math.max(max ?? key, key);
  }

  var total = argumentLengths.totalCount;
  print("\n--- $label ($total total) ---");

  var cumulative = 0;
  for (var i = min; i <= max; i++) {
    var count = argumentLengths.count(i);
    if (count == 0) continue;

    cumulative += count;

    var countString = count.toString().padLeft(7);
    var iString = i.toString().padLeft(max.toString().length);
    var percent = 100 * count / total;
    var percentString = percent.toStringAsFixed(3).padLeft(7);

    var cumulativePercent = 100 * cumulative / total;
    var cumulativePercentString =
        cumulativePercent.toStringAsFixed(3).padLeft(7);

    var bar = "*" * (count / total * 60).toInt();
    print("$iString: $countString ($percentString%) ($cumulativePercentString cuml) $bar");
  }

  print("Median ${argumentLengths.median}");
}

class Visitor extends RecursiveAstVisitor<void> {
  final String path;
  bool showedPath = false;

  Visitor(this.path);

  @override
  void visitCascadeExpression(CascadeExpression node) {
    for (var section in node.cascadeSections) {
      if (section is MethodInvocation) {
        _countCall(section.methodName, node.target, section.argumentList);
      }
    }

    return super.visitCascadeExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _countCall(node.methodName, node.target, node.argumentList);

    return super.visitMethodInvocation(node);
  }

  void _countCall(SimpleIdentifier name, Expression target, ArgumentList args) {
    if (name.name != "addAll") return;

    // See if the target is a collection literal.
    while (target is MethodInvocation) {
      target = (target as MethodInvocation).target;
    }

    // TODO: What about `new List()`, etc.?
    if (target is ListLiteral || target is MapLiteral) {
      if (args.arguments.length == 1) {
        var arg = args.arguments[0];
        argumentStrings.add(arg.toString());
        argumentLengths.add(arg.length);
      }
    }
  }
}

temp() {
  [].addAll([]);
  []
    ..addAll([])
    ..removeLast()
    ..addAll([]);
  [].addAll([]);
  [].where(null).toList().addAll([]);
  [].where(null).toList()..addAll([]);

  ({}.addAll({}));
  ({}
    ..addAll({})
    ..remove(null)
    ..addAll({}));

  Set().addAll([]);
}
