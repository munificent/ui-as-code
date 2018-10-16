// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:ui_as_code_tools/histogram.dart';
import 'package:ui_as_code_tools/parser.dart';

/// Pairs of tokens that appear next to each other.
final pairs = new Histogram<String>();

/// Pairs of tokens that appear on different lines.
final newlinePairs = new Histogram<String>();

/// Pairs of tokens that appear with a semicolon between them.
final semicolonPairs = new Histogram<String>();

/// Pairs of tokens that appear on the same line with no semicolon between them.
final noNewlineNoSemicolonPairs = new Histogram<String>();

/// Pairs of tokens that appear on the same with a semicolon between them.
final noNewlineSemicolonPairs = new Histogram<String>();

/// Pairs of tokens that appear on different lines, without a semicolon between
/// them.
final newlineNoSemicolonPairs = new Histogram<String>();

/// Pairs of tokens that appear on different lines, with a semicolon between
/// them.
final newlineSemicolonPairs = new Histogram<String>();

void main(List<String> arguments) {
  var errorListener = new ErrorListener();

  forEachDartFile(arguments[0], callback: (file, relative) {
    print(relative);

    var source = file.readAsStringSync();
    var reader = new CharSequenceReader(source);
    var stringSource = new StringSource(source, relative);
    var scanner = new Scanner(stringSource, reader, errorListener);
    var token = scanner.tokenize();
    var lines = new LineInfo(scanner.lineStarts);

    while (token.type != TokenType.EOF) {
      pairs.add(_pair(token, token.next));

      if (lines.getLocation(token.offset).lineNumber !=
          lines.getLocation(token.next.offset).lineNumber) {
        newlinePairs.add(_pair(token, token.next));
      }

      if (token.next.type == TokenType.SEMICOLON) {
        semicolonPairs.add(_pair(token, token.next.next));

        if (lines.getLocation(token.offset).lineNumber !=
            lines.getLocation(token.next.next.offset).lineNumber) {
          newlineSemicolonPairs.add(_pair(token, token.next.next));
        } else {
          noNewlineSemicolonPairs.add(_pair(token, token.next.next));
        }
      } else if (token.type != TokenType.SEMICOLON) {
        if (lines.getLocation(token.offset).lineNumber !=
            lines.getLocation(token.next.offset).lineNumber) {
          newlineNoSemicolonPairs.add(_pair(token, token.next));
        } else {
          noNewlineNoSemicolonPairs.add(_pair(token, token.next));
        }
      }

      token = token.next;
    }
  });

  pairs.printDescending("Pairs");
  newlinePairs.printDescending("Newline Pairs");
  semicolonPairs.printDescending("Semicolon Pairs");

  noNewlineNoSemicolonPairs.printDescending("No Newline No Semicolon");
  noNewlineSemicolonPairs.printDescending("No Newline Semicolon");
  newlineNoSemicolonPairs.printDescending("Newline No Semicolon");
  newlineSemicolonPairs.printDescending("Newline Semicolon");
}

String _pair(Token a, Token b) =>
    "${a.type} ${b.type}".replaceAll("STRING_INT", "IDENTIFIER").toLowerCase();
