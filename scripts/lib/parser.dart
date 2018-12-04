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
    {bool includeTests,
    bool includeLanguageTests,
    bool includeProtobufs,
    Function(File file, String relative) callback}) {
  includeTests ??= true;
  includeLanguageTests ??= false;
  includeProtobufs ??= false;

  if (new File(path).existsSync()) {
    callback(new File(path), p.relative(path, from: path));
    return;
  }

  for (var entry in new Directory(path).listSync(recursive: true)) {
    if (!entry.path.endsWith(".dart")) continue;

    // For unknown reasons, some READMEs have a ".dart" extension. They aren't
    // Dart files.
    if (entry.path.endsWith("README.dart")) continue;

    if (!includeLanguageTests) {
      if (entry.path.contains("/sdk/tests/")) continue;
      if (entry.path.contains("/testcases/")) continue;
      if (entry.path.contains("/sdk/runtime/tests/")) continue;
      if (entry.path.contains("/linter/test/_data/")) continue;
      if (entry.path.contains("/analyzer/test/")) continue;
      if (entry.path.contains("/dev_compiler/test/")) continue;
      if (entry.path.contains("/analyzer_cli/test/")) continue;
      if (entry.path.contains("/analysis_server/test/")) continue;
      if (entry.path.contains("/kernel/test/")) continue;
    }

    if (!includeTests) {
      if (entry.path.contains("/test/")) continue;
      if (entry.path.endsWith("_test.dart")) continue;
    }

    // Don't care about cached packages.
    if (entry.path.contains("sdk/third_party/pkg/")) continue;
    if (entry.path.contains("sdk/third_party/pkg_tested/")) continue;
    if (entry.path.contains("/.dart_tool/")) continue;

    // Don't care about generated protobuf code.
    if (!includeProtobufs) {
      if (entry.path.endsWith(".pb.dart")) continue;
      if (entry.path.endsWith(".pbenum.dart")) continue;
    }

    var relative = p.relative(entry.path, from: path);
//    if (p.dirname(relative) != lastDir) {
//      print(relative);
//      lastDir = p.dirname(relative);
//    }

    callback(entry, relative);
  }
}

void parsePath(String path,
    {bool includeTests,
    bool includeLanguageTests,
    bool includeProtobufs,
    Visitor Function(String) createVisitor}) {
  forEachDartFile(path,
      includeTests: includeTests,
      includeLanguageTests: includeLanguageTests,
      includeProtobufs: includeProtobufs, callback: (file, relative) {
    _parseFile(file, relative, createVisitor);
  });
}

void _parseFile(
    File file, String shortPath, Visitor Function(String) createVisitor) {
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
  bool _hadError = false;

  bool get hadError => _hadError;

  void onError(AnalysisError error) {
    _hadError = true;
    print(error);
  }
}
