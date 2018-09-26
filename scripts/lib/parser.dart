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

Token tokenizeString(String source) {
  var errorListener = new ErrorListener();

  // Tokenize the source.
  var reader = new CharSequenceReader(source);
  var stringSource = new StringSource(source, "<string>");
  var scanner = new Scanner(stringSource, reader, errorListener);
  return scanner.tokenize();
}

void forEachDartFile(
    String path, Function(File file, String relative) callback) {
  if (new File(path).existsSync()) {
    callback(new File(path), p.relative(path, from: path));
    return;
  }

  for (var entry in new Directory(path).listSync(recursive: true)) {
    if (!entry.path.endsWith(".dart")) continue;

    // Don't care about tests.
    if (entry.path.contains("/test/")) continue;

    // Don't care about cached packages.
    if (entry.path.contains("/.dart_tool/")) continue;

    callback(entry, p.relative(entry.path, from: path));
  }
}

void parsePath(String path, AstVisitor<void> Function(String) createVisitor) {
  forEachDartFile(path, (file, relative) {
    parseFile(file, relative, (path, _) => createVisitor(path));
  });
}

void parsePathWithLineInfo(
    String path, AstVisitor<void> Function(String, LineInfo) createVisitor) {
  forEachDartFile(path, (file, relative) {
    parseFile(file, relative, createVisitor);
  });
}

void parseFile(File file, String shortPath,
    AstVisitor<void> Function(String, LineInfo) createVisitor) {
  var source = file.readAsStringSync();

  var errorListener = new ErrorListener();

  // Tokenize the source.
  var reader = new CharSequenceReader(source);
  var stringSource = new StringSource(source, file.path);
  var scanner = new Scanner(stringSource, reader, errorListener);
  var startToken = scanner.tokenize();
  var lineInfo = new LineInfo(scanner.lineStarts);

  // Parse it.
  var parser = new Parser(stringSource, errorListener);
  parser.enableOptionalNewAndConst = true;

  var node = parser.parseCompilationUnit(startToken);
  node.accept(createVisitor(shortPath, lineInfo));
}

/// A simple [AnalysisErrorListener] that just collects the reported errors.
class ErrorListener implements AnalysisErrorListener {
  void onError(AnalysisError error) {
//    print(error);
  }
}
