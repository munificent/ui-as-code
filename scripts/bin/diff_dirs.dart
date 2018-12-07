// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:path/path.dart' as p;

final headerPattern = RegExp(r"^(---|\+\+\+) (\S+)");

/// Diffs two directories and then pretties up the output taking into account
/// the special formatter error comments produced by the hacked dart_style.
void main(List<String> arguments) {
  var from = arguments[0];
  var to = arguments[1];

  var issues = KnownIssues();
  if (arguments.length > 2) {
    issues = KnownIssues.parse(arguments[2]);
  }

  var diffs = 0;
  var ignored = 0;
  var knownFalsePositives = 0;
  var knownBreakages = 0;

  Diff diff;
  String fromPath;

  finishDiff() {
    if (diff == null) return;

    // Whitelist the known ones.
    for (var path in issues.breakingChanges) {
      if (diff.fromPath.endsWith(path)) {
        knownBreakages++;
        return;
      }
    }

    for (var path in issues.falsePositives) {
      if (diff.fromPath.endsWith(path)) {
        knownFalsePositives++;
        return;
      }
    }

    // If the only differences are whitespace, ignore them.
    var skipDiff = true;
    for (var line in diff.lines) {
      if ((line.startsWith("-") || line.startsWith("+")) &&
          line.trim().length > 1 &&
          line.substring(1).trim() != ";") {
        skipDiff = false;
        break;
      }
    }

    if (skipDiff) {
      ignored++;
      return;
    }

    // If the only differences are moved semicolons on lines containing
    // comments, it's because it moved the semicolon before the comment.
    // Ignore those.
    var removes = <String>[];
    var adds = <String>[];
    for (var line in diff.lines) {
      if (line.startsWith("-")) removes.add(line);
      if (line.startsWith("+")) adds.add(line);
    }

    if (removes.isNotEmpty && removes.length == adds.length) {
      skipDiff = true;

      for (var i = 0; i < removes.length; i++) {
        var remove = removes[i];
        var add = adds[i];
        if ((remove.contains("//") || remove.contains("/*")) &&
            remove.substring(1).replaceAll(";", "").replaceAll(" ", "") ==
                add.substring(1).replaceAll(";", "").replaceAll(" ", "")) {
          // We can ignore this.
        } else {
          // Got a real diff.
          skipDiff = false;
          break;
        }
      }

      if (skipDiff) {
        ignored++;
        return;
      }
    }

    var fromParts = p.split(diff.fromPath);
    var toParts = p.split(diff.toPath);

    var parts = <String>[];
    for (var i = 0; i < fromParts.length; i++) {
      if (fromParts[i] != toParts[i]) {
        parts.add("(${fromParts[i]}|${toParts[i]})");
      } else if (parts.isNotEmpty) {
        parts.add(fromParts[i]);
      }
    }

    var errorInFrom = diff.lines.any((line) =>
        line.startsWith("-") &&
        line.contains(
            "Could not format because the source could not be parsed"));
    var errorInTo = diff.lines.any((line) =>
        line.startsWith("+") &&
        line.contains(
            "Could not format because the source could not be parsed"));
    var errorInBoth = diff.lines.any((line) => line.startsWith(
        " // Could not format because the source could not be parsed"));

    // Ignore differences if both before and after had compile errors. This is
    // usually just the different file name or error location.
    if (errorInBoth) {
      ignored++;
      return;
    }

    var unionPath = p.joinAll(parts);
    print(unionPath);

    if (errorInFrom && errorInTo) {
      print("Error in both:");
      for (var line in diff.lines) print(line);
    } else if (errorInFrom) {
      print("Error in from:");
      for (var line in diff.lines) {
        if (line.startsWith("-")) print(line.substring(4));
      }
    } else if (errorInTo) {
      print("Error in to:");
      for (var line in diff.lines) {
        if (line.startsWith("+")) print(line.substring(4));
      }
    } else {
      for (var line in diff.lines) print(line);
    }

    print("");
    diffs++;
  }

  var stdout = Process.runSync("diff", ["-ru", from, to]).stdout as String;
  for (var line in stdout.split("\n")) {
    var match = headerPattern.firstMatch(line);
    if (match != null) {
      if (line.startsWith("---")) {
        fromPath = match.group(2);
      } else {
        finishDiff();
        diff = Diff(fromPath, match.group(2));
      }
    } else if (line.startsWith("-") && !line.startsWith("---") ||
        line.startsWith("+") && !line.startsWith("+++") ||
        line.startsWith(" ")) {
      diff.lines.add(line);
    }
  }

  finishDiff();
  print("$diffs differences, $ignored ignored, $knownBreakages breakages, "
      "$knownFalsePositives false positives");
}

class Diff {
  final String fromPath;
  final String toPath;

  final List<String> lines = [];

  Diff(this.fromPath, this.toPath);
}

class KnownIssues {
  /// Parse from a simple config file.
  ///
  /// Lines that start with "-" followed by a path are known breaking changes.
  /// Lines that start with "+" followed by a path are false positives.
  /// Lines that start with "//" are comments.
  static KnownIssues parse(String path) {
    var issues = KnownIssues();

    for (var line in File(path).readAsLinesSync()) {
      if (line.startsWith("//")) {
        // Comment.
      } else if (line.trim() == "") {
        // Ignore empty lines.
      } else if (line.startsWith("-")) {
        issues.breakingChanges.add(line.substring(1));
      } else if (line.startsWith("+")) {
        issues.falsePositives.add(line.substring(1));
      } else {
        throw FormatException("Unexpected line:\n$line");
      }
    }

    return issues;
  }

  /// Places where there is a known diff because of a deliberate breaking
  /// change.
  final List<String> breakingChanges = [];

  /// Places where the diff is because of a bug in the prototype implementation
  /// or some other issue that wouldn't affect real users.
  final List<String> falsePositives = [];
}