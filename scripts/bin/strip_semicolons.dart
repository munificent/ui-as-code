// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:path/path.dart' as p;

import 'package:ui_as_code_tools/parser.dart';

/// Remove semicolons from Dart source files.
///
/// Uses a lexer to correctly remove them from code while leaving them alone
/// in comments, string literals, etc.
void main(List<String> arguments) {
  var stripped = 0;
  var remaining = 0;

  forEachDartFile(arguments[0], includeTests: true, callback: (file, relative) {
    print(relative);

    var buffer = new StringBuffer();

    var source = file.readAsStringSync();
    var previousOffset = 0;

    var errorListener = new ErrorListener();

    // Tokenize the source.
    var reader = new CharSequenceReader(source);
    var stringSource = new StringSource(source, "<string>");
    var scanner = new Scanner(stringSource, reader, errorListener);
    var lineInfo = new LineInfo(scanner.lineStarts);

    var token = scanner.tokenize();

    var nesting = <String>[];
    push(String label) => nesting.add(label);
    pop(String label) {
      if (nesting.last != label) {
        throw "Misnesting at $token (${lineInfo.getLocation(token.offset)})";
      }

      nesting.removeLast();
    }

    // Don't remove semicolons in C-style for loop clauses.
    isInForLoop() => nesting.length > 2 && nesting[nesting.length - 2] == "for";

    while (!token.isEof) {
      // Write whitespace between this and the previous token.
      buffer.write(source.substring(previousOffset, token.offset));

      if (token.type != TokenType.SEMICOLON) {
        buffer.write(token.lexeme);
      } else if (isInForLoop()) {
        buffer.write(token.lexeme);
        remaining++;
      } else {
        // If we're removing a semicolon that has more code after it, insert a
        // newline, as in:
        //
        //     callback() { foo(); bar(); }
        var line = lineInfo.getLocation(token.offset).lineNumber;
        var nextLine = lineInfo.getLocation(token.next.offset).lineNumber;

        if (line == nextLine &&
            token.next.type != TokenType.CLOSE_CURLY_BRACKET) {
          buffer.writeln();
        }

        stripped++;
      }

      if (token.keyword == Keyword.FOR) push("for");
      if (token.type == TokenType.OPEN_PAREN) push("(");
      if (token.type == TokenType.OPEN_SQUARE_BRACKET) push("[");
      if (token.type == TokenType.OPEN_CURLY_BRACKET) push("{");
      if (token.type == TokenType.STRING_INTERPOLATION_EXPRESSION) push("{");
      if (token.type == TokenType.CLOSE_PAREN) {
        pop("(");
        if (nesting.isNotEmpty && nesting.last == "for") nesting.removeLast();
      }
      if (token.type == TokenType.CLOSE_SQUARE_BRACKET) pop("[");
      if (token.type == TokenType.CLOSE_CURLY_BRACKET) pop("{");

      previousOffset = token.end;
      token = token.next;
    }

    // Write whitespace and comments after last token.
    buffer.write(source.substring(previousOffset, token.offset));

    if (arguments.length > 1) {
      var outPath = p.join(arguments[1], relative);
      new Directory(p.dirname(outPath)).createSync(recursive: true);
      new File(outPath).writeAsStringSync(buffer.toString());
    } else {
      print(buffer.toString());
    }
  });

  print("Removed $stripped semicolons, $remaining remain.");
}
