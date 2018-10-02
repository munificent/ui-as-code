// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:ui_as_code_tools/parser.dart';

var trailingRegex = RegExp(r";$");
var beforeCommentRegex = RegExp(r";(\s*//.*)$");
var beforeBraceRegex = RegExp(r";(\s*})");

void main(List<String> arguments) {
  forEachDartFile(arguments[0], (file, relative) {
    print(relative);
    var outPath = p.join(arguments[1], relative);
    new Directory(p.dirname(outPath)).createSync(recursive: true);

    var buffer = new StringBuffer();
    for (var line in file.readAsLinesSync()) {
      // Hackish. Don't remove trailing semicolons in code samples in doc
      // comments, commented out code, etc. Minimizes spurious diffs between
      // the two formatted corpora.
      if (!line.contains("//")) {
        line = line.replaceAll(trailingRegex, "");
      }

      line = line.replaceAllMapped(beforeCommentRegex, (match) => match.group(1));
      line = line.replaceAllMapped(beforeBraceRegex, (match) => match.group(1));

      buffer.writeln(line);
    }

    new File(outPath).writeAsStringSync(buffer.toString());
  });
}
