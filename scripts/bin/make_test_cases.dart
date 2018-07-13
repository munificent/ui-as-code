// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

void main(List<String> arguments) {
  var buffer = StringBuffer();

  var indent = 0;
  var needLine = false;

  write(String s) {
    if (s.endsWith("}") || s.endsWith(")")) {
      indent--;
      needLine = true;
    }

    if (needLine) {
      buffer.writeln();
      buffer.write("  " * indent);
      needLine = false;
    }

    buffer.write(s);
    if (s.endsWith("{") || s.endsWith("(")) {
      indent++;
      needLine = true;
    } else if (s.endsWith(";") || s.endsWith(",")) {
      needLine = true;
    }

    if (s.endsWith("}")) {
      buffer.writeln();
      buffer.writeln();
    }
  }

  // As in, there are 10 build methods with 1 nesting level, 9 build methods
  // with 2 nesting levels, 8 build methods with 3 nesting levels ... 1 build
  // method with 10 nesting levels.

  // Suppose that all arguments were always at the leaves, and that there were N
  // build methods with 11-N nesting levels.
  for (var n = 1; n <= 10; n++) {
    for (var i = 1; i <= 11 - n; i++) {
      write("Widget atLeaves_nest${n}_build$i() {");
      write("return ");
      for (var level = 1; level <= n; level++) {
        write("Widget(");
      }

      write("argument,");

      for (var level = 1; level <= n; level++) {
        write(")");
        if (level != n) write(",");
      }

      write(";");
      write("}");
    }
  }

  new File("temp/case_1.dart").writeAsStringSync(buffer.toString());
  buffer.clear();

  // Suppose that all arguments were always exactly in the middle (with as many
  // ancestor widgets as the argument-sporting widget had descendant widgets,
  // rounding up), and that there were N build methods with 11-N nesting levels.
  for (var n = 1; n <= 10; n++) {
    for (var i = 1; i <= 11 - n; i++) {
      write("Widget atMiddle_nest${n}_build$i() {");
      write("return ");
      for (var level = 1; level <= n; level++) {
        write("Widget(");
        if (level == (n / 2).ceil()) write("argument,");
      }

      for (var level = 1; level <= n; level++) {
        write(")");
        if (level != n) write(",");
      }

      write(";");
      write("}");
    }
  }

  new File("temp/case_2.dart").writeAsStringSync(buffer.toString());
  buffer.clear();

  // Suppose that every level had one argument, and that there were N build
  // methods with 11-N nesting levels.
  for (var n = 1; n <= 10; n++) {
    for (var i = 1; i <= 11 - n; i++) {
      write("Widget atEvery_nest${n}_build$i() {");
      write("return ");
      for (var level = 1; level <= n; level++) {
        write("Widget(");
        write("argument,");
      }

      for (var level = 1; level <= n; level++) {
        write(")");
        if (level != n) write(",");
      }

      write(";");
      write("}");
    }
  }

  new File("temp/case_3.dart").writeAsStringSync(buffer.toString());
  buffer.clear();
}
