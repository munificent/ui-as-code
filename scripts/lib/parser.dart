// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:path/path.dart' as p;

import 'visitor.dart';

Token tokenizeString(String source) {
  var errorListener = new ErrorListener();

  // Tokenize the source.
  var reader = new CharSequenceReader(source);
  var stringSource = new StringSource(source, "<string>");
  var scanner = new Scanner(stringSource, reader, errorListener);
  return scanner.tokenize();
}

void forEachDartFile(String path,
    {bool includeTests, Function(File file, String relative) callback}) {
  includeTests ??= false;

  if (new File(path).existsSync()) {
    callback(new File(path), p.relative(path, from: path));
    return;
  }

  for (var entry in new Directory(path).listSync(recursive: true)) {
    if (!entry.path.endsWith(".dart")) continue;

    if (!includeTests) {
      if (entry.path.contains("/test/")) continue;
      if (entry.path.contains("/sdk/tests/")) continue;
      if (entry.path.contains("/testcases/")) continue;
      if (entry.path.endsWith("_test.dart")) continue;
    }

    // Don't care about cached packages.
    if (entry.path.contains("/.dart_tool/")) continue;

    callback(entry, p.relative(entry.path, from: path));
  }
}

void parsePath(String path,
    {bool includeTests, Visitor Function(String) createVisitor}) {
  forEachDartFile(path, includeTests: includeTests, callback: (file, relative) {
    _parseFile(file, relative, createVisitor);
  });
}

void _parseFile(File file, String shortPath,
    Visitor Function(String) createVisitor) {
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

  var visitor = createVisitor(shortPath);
  visitor.bind(source, new LineInfo(scanner.lineStarts));

  var node = parser.parseCompilationUnit(startToken);
  node.accept(visitor);
}

/// A simple [AnalysisErrorListener] that just collects the reported errors.
class ErrorListener implements AnalysisErrorListener {
  void onError(AnalysisError error) {
//    print(error);
  }
}
