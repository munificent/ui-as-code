// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:ui_as_code_tools/parameter_freedom/ast.dart';
import 'package:ui_as_code_tools/parameter_freedom/subtype.dart';

void main(List<String> arguments) {
  print("void testSubtypeExhaustive() {");
  for (var includeRest in [false, true]) {
    for (var superBits = 0; superBits < 32; superBits++) {
      var superSig = makeSig(superBits, includeRest);
      print("  signature(\"$superSig\"); // ${bindingSig(superSig)}");
      for (var subBits = 0; subBits < 32; subBits++) {
        var subSig = makeSig(subBits, includeRest);

        if (superSig.toString() == subSig.toString()) continue;

        if (isSubtype(superSig, subSig)) {
          print("  expectSubtype(\"$subSig\"); // ${bindingSig(subSig)}");
        } else {
          print("  expectNotSubtype(\"$subSig\"); // ${bindingSig(subSig)}");
        }
      }
      print("");
    }
  }
  print("}");
}

Signature makeSig(int bits, bool includeRest) {
  var params = [
    Parameter("int", "a", false, bits & 16 == 0),
    Parameter("int", "b", false, bits & 8 == 0),
    Parameter("int", "c", false, bits & 4 == 0),
    Parameter("int", "d", false, bits & 2 == 0),
    Parameter("int", "e", false, bits & 1 == 0),
  ];

  if (includeRest) params.insert(2, Parameter("List", "r", true, false));

  return Signature(params, []);
}

String bindingSig(Signature signature) {
  return signature.positional
      .map((param) => signature.priority(param))
      .join(",");
}
