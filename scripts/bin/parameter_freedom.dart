// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:ui_as_code_tools/parameter_freedom/ast.dart';
import 'package:ui_as_code_tools/parameter_freedom/parser.dart';
import 'package:ui_as_code_tools/parameter_freedom/subtype.dart';

Signature _signature;

bool _showedSignature = false;
int _passed = 0;
int _failed = 0;

void main(List<String> arguments) {
  testBinding();
  testSubtype();
  testSubtypeExhaustive();

  print("$_passed/${_passed + _failed} tests passed.");
}

void testBinding() {
  signature("int a, int b");
  expectBind("", error: "Not enough positional arguments.");
  expectBind("3", error: "Not enough positional arguments.");
  expectBind("3, 4", binds: "a: 3, b: 4");
  expectBind("3, 4, 5", error: "Too many positional arguments.");

  signature("[int a, int b]");
  expectBind("", binds: "");
  expectBind("3", binds: "a: 3");
  expectBind("3, 4", binds: "a: 3, b: 4");
  expectBind("3, 4, 5", error: "Too many positional arguments.");

  signature("[int a], int b, [int c], int d, [int e]");
  expectBind("4", error: "Not enough positional arguments.");
  expectBind("4, 5", binds: "b: 4, d: 5");
  expectBind("4, 5, 6", binds: "a: 4, b: 5, d: 6");
  expectBind("4, 5, 6, 7", binds: "a: 4, b: 5, c: 6, d: 7");
  expectBind("4, 5, 6, 7, 8", binds: "a: 4, b: 5, c: 6, d: 7, e: 8");

  signature("[int a], List ...b, [int c]");
  expectBind("", binds: "b: []");
  expectBind("4", binds: "a: 4, b: []");
  expectBind("4, 5", binds: "a: 4, b: [], c: 5");
  expectBind("4, 5, 6", binds: "a: 4, b: [5], c: 6");
  expectBind("4, 5, 6, 7", binds: "a: 4, b: [5, 6], c: 7");

  signature("[int a], List ...b, int c");
  expectBind("2", binds: "b: [], c: 2");
  expectBind("2, 3", binds: "a: 2, b: [], c: 3");
  expectBind("2, 3, 4", binds: "a: 2, b: [3], c: 4");
  expectBind("2, 3, 4, 5", binds: "a: 2, b: [3, 4], c: 5");

  signature("int a, [int b, int c], int d");
  expectBind("1, 2", binds: "a: 1, d: 2");
  expectBind("1, 2, 3", binds: "a: 1, b: 2, d: 3");
  expectBind("1, 2, 3, 4", binds: "a: 1, b: 2, c: 3, d: 4");
}

void testSubtype() {
  signature("");
  expectSubtype("");
  expectNotSubtype("int a");
  expectSubtype("[int a]");
  expectSubtype("[int a, int b]");
  expectSubtype("List ...r");
  expectSubtype("[int a], List ...r, [int b]");

  signature("int a, bool b, String c");
  expectSubtype("int c, bool d, String e");
  expectNotSubtype("int c, bool d, num e"); // Wrong param type.
  expectNotSubtype("int c, bool d"); // Not enough params.
  expectNotSubtype("int c, bool d, String e, num f"); // Too many required.

  // Can append optional, but nowhere else.
  signature("int a, [bool b], String c");
  expectSubtype("int c, [bool d], String e");
  expectSubtype("int c, [bool d], String e, [int f]");
  expectSubtype("int c, [bool d], String e, [int f, bool g]");
  expectNotSubtype("[int f], int c, [bool d], String e");
  expectNotSubtype("int c, [int f], [bool d], String e");
  expectNotSubtype("int c, [bool d], [int f], String e");

  // Optionals must stay optional (trailing).
  signature("int a, [int b, int c]");
  expectSubtype("int z, [int y, int x]");
  expectNotSubtype("int z, int y, [int x]");
  expectNotSubtype("int z, [int y], int x");
  expectNotSubtype("int z, int y, int x");

  // Optionals must stay optional (middle).
  signature("int a, [int b], [int c], int d");
  expectSubtype("int z, [int y, int x], int d");
  expectNotSubtype("int z, int y, [int x], int d");
  expectNotSubtype("int z, [int y], int x, int d");
  expectNotSubtype("int z, int y, int x, int d");

  // Optionals must stay optional (leading).
  signature("[int b], [int c], int d");
  expectSubtype("[int y, int x], int d");
  expectNotSubtype("int y, [int x], int d");
  expectNotSubtype("[int y], int x, int d");
  expectNotSubtype("int y, int x, int d");

  // Cannot add optionals if supertype has rest.
  signature("int a, [int b], List ...c");
  expectSubtype("int a, [int b], List ...c");
  expectNotSubtype("int a, [int b], List ...c, [int d]");
  expectNotSubtype("int a, [int b], [int d], List ...c");

  // Rests must match.
  signature("int a, List ...b, List c");
  expectSubtype("int c, List ...d, List e");
  expectNotSubtype("int c, List d, List e");
  signature("int a, List b, List c");
  expectNotSubtype("int c, List ...d, List e");

  // Can append rest parameter.
  signature("int a, [bool b], String c");
  expectSubtype("int a, [bool b], String c, List ...r");
  expectNotSubtype("List ...r, int a, [bool b], String c");
  expectNotSubtype("int a, List ...r, [bool b], String c");
  expectNotSubtype("int a, [bool b], List ...r, String c");

  // Rest is not substitute for optional.
  signature("bool a, [int b]");
  expectNotSubtype("bool a, List ...b");

  signature("bool a, List ...b");
  expectNotSubtype("bool a, [int b]");

  // Trailing required parameters can become optional.
//  signature("bool a, [int b], String c, num d, double e");
//  expectSubtype("bool a, [int b], String c, num d, [double e]");
//  expectSubtype("bool a, [int b], String c, [num d, double e]");
//  expectSubtype("bool a, [int b, String c, num d, double e]");
}

void signature(String source) {
  _signature = Parser(source).parseSignature();
  _showedSignature = false;
}

void fail(String invocation, String message) {
  showSignature();
  print("FAIL ($invocation): $message.");
  _failed++;
}

void pass(String invocation, String message) {
//  showSignature();
//  print("PASS ($invocation): $message");
  _passed++;
}

void showSignature() {
  if (_showedSignature) return;
  print("($_signature)");
  _showedSignature = true;
}

void expectBind(String invocation, {String binds, String error}) {
  var expect = <String, Object>{};
  if (binds != null) {
    for (var arg in Parser(binds).parseInvocation()) {
      expect[arg.name] = arg.value;
    }
  }

  // We only prototype the logic for positional arguments since binding named
  // arguments to parameters is unchanged.
  var arguments =
      Parser(invocation).parseInvocation().map((arg) => arg.value).toList();
  var bindings = bind(arguments, _signature);

  if (bindings.containsKey("error")) {
    if (error == null) {
      fail(invocation, "Expected $expect but got error '${bindings["error"]}'");
    } else if (error != bindings["error"]) {
      fail(invocation,
          "Expected error '$error' but got error '${bindings["error"]}'");
    }

    return;
  }

  if (error != null) {
    fail(invocation, "Expected error '$error' but bound $bindings");
  }

  var keys = expect.keys.toSet();
  keys.addAll(bindings.keys);

  var failed = false;
  for (var key in keys) {
    if (!objectsEqual(expect[key], bindings[key])) {
      fail(invocation,
          "Expected '$key' to be '${expect[key]}', but was '${bindings[key]}'");
      failed = true;
    }
  }

  if (!failed) pass(invocation, bindings.toString());
}

void expectSubtype(String other) {
  _testSubtype(other, true);
}

void expectNotSubtype(String other) {
  _testSubtype(other, false);
}

void _testSubtype(String other, bool expect) {
  var actual = isSubtype(_signature, Parser(other).parseSignature());
  if (expect) {
    if (actual) {
      pass(other, "Is subtype");
    } else {
      fail(other, "Is not subtype and should be");
    }
  } else {
    if (actual) {
      fail(other, "Is subtype and should not be");
    } else {
      pass(other, "Is not subtype");
    }
  }
}

bool objectsEqual(Object a, Object b) {
  if (a == b) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  return false;
}

Map<String, Object> bind(List<Object> arguments, Signature signature) {
  error(String message) => {"error": message};
  var bindings = <String, Object>{};

  // The required parameters.
  var required =
      signature.positional.where((param) => param.isRequired).toList();

  // The optional parameters.
  var optional =
      signature.positional.where((param) => param.isOptional).toList();

  // The position of the rest parameter or -1 if there is none.
  var restParam = signature.positional.indexWhere((param) => param.isRest);

  // How many arguments are left for the rest parameter (if any).
  var providedRest = arguments.length - required.length - optional.length;

  if (arguments.length < required.length) {
    return error("Not enough positional arguments.");
  }

  if (providedRest > 0 && restParam == -1) {
    return error("Too many positional arguments.");
  }

  if (restParam != -1) {
    if (providedRest > 0) {
      var restArgs = arguments.sublist(restParam, restParam + providedRest);
      arguments.replaceRange(restParam, restParam + providedRest, [restArgs]);
    } else {
      bindings[signature.positional[restParam].name] = [];
    }
  }

  assert(arguments.length <= signature.positional.length);

  var argIndex = 0;
  for (var param in signature.positional) {
    if (signature.bindingOrder(param) < arguments.length) {
      bindings[param.name] = arguments[argIndex++];
    }
  }

  return bindings;
}

void testSubtypeExhaustive() {
  signature("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectNotSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectNotSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectNotSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4
  expectSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectNotSubtype("int a, int b, int c, int d, int e"); // 0,1,2,3,4

  signature("int a, int b, int c, int d, int e"); // 0,1,2,3,4
  expectSubtype("[int a, int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("[int a, int b, int c, int d], int e"); // 1,2,3,4,0
  expectNotSubtype("[int a, int b, int c], int d, [int e]"); // 1,2,3,0,4
  expectNotSubtype("[int a, int b, int c], int d, int e"); // 2,3,4,0,1
  expectNotSubtype("[int a, int b], int c, [int d, int e]"); // 1,2,0,3,4
  expectNotSubtype("[int a, int b], int c, [int d], int e"); // 2,3,0,4,1
  expectNotSubtype("[int a, int b], int c, int d, [int e]"); // 2,3,0,1,4
  expectNotSubtype("[int a, int b], int c, int d, int e"); // 3,4,0,1,2
  expectNotSubtype("[int a], int b, [int c, int d, int e]"); // 1,0,2,3,4
  expectNotSubtype("[int a], int b, [int c, int d], int e"); // 2,0,3,4,1
  expectNotSubtype("[int a], int b, [int c], int d, [int e]"); // 2,0,3,1,4
  expectNotSubtype("[int a], int b, [int c], int d, int e"); // 3,0,4,1,2
  expectNotSubtype("[int a], int b, int c, [int d, int e]"); // 2,0,1,3,4
  expectNotSubtype("[int a], int b, int c, [int d], int e"); // 3,0,1,4,2
  expectNotSubtype("[int a], int b, int c, int d, [int e]"); // 3,0,1,2,4
  expectNotSubtype("[int a], int b, int c, int d, int e"); // 4,0,1,2,3
  expectSubtype("int a, [int b, int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, [int b, int c, int d], int e"); // 0,2,3,4,1
  expectNotSubtype("int a, [int b, int c], int d, [int e]"); // 0,2,3,1,4
  expectNotSubtype("int a, [int b, int c], int d, int e"); // 0,3,4,1,2
  expectNotSubtype("int a, [int b], int c, [int d, int e]"); // 0,2,1,3,4
  expectNotSubtype("int a, [int b], int c, [int d], int e"); // 0,3,1,4,2
  expectNotSubtype("int a, [int b], int c, int d, [int e]"); // 0,3,1,2,4
  expectNotSubtype("int a, [int b], int c, int d, int e"); // 0,4,1,2,3
  expectSubtype("int a, int b, [int c, int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, [int c, int d], int e"); // 0,1,3,4,2
  expectNotSubtype("int a, int b, [int c], int d, [int e]"); // 0,1,3,2,4
  expectNotSubtype("int a, int b, [int c], int d, int e"); // 0,1,4,2,3
  expectSubtype("int a, int b, int c, [int d, int e]"); // 0,1,2,3,4
  expectNotSubtype("int a, int b, int c, [int d], int e"); // 0,1,2,4,3
  expectSubtype("int a, int b, int c, int d, [int e]"); // 0,1,2,3,4

  signature("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectNotSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectNotSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectNotSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
  expectSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectNotSubtype("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4

  signature("int a, int b, List ...r, int c, int d, int e"); // 0,1,5,2,3,4
  expectSubtype("[int a, int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("[int a, int b], List ...r, [int c, int d], int e"); // 1,2,5,3,4,0
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, [int e]"); // 1,2,5,3,0,4
  expectNotSubtype("[int a, int b], List ...r, [int c], int d, int e"); // 2,3,5,4,0,1
  expectNotSubtype("[int a, int b], List ...r, int c, [int d, int e]"); // 1,2,5,0,3,4
  expectNotSubtype("[int a, int b], List ...r, int c, [int d], int e"); // 2,3,5,0,4,1
  expectNotSubtype("[int a, int b], List ...r, int c, int d, [int e]"); // 2,3,5,0,1,4
  expectNotSubtype("[int a, int b], List ...r, int c, int d, int e"); // 3,4,5,0,1,2
  expectNotSubtype("[int a], int b, List ...r, [int c, int d, int e]"); // 1,0,5,2,3,4
  expectNotSubtype("[int a], int b, List ...r, [int c, int d], int e"); // 2,0,5,3,4,1
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, [int e]"); // 2,0,5,3,1,4
  expectNotSubtype("[int a], int b, List ...r, [int c], int d, int e"); // 3,0,5,4,1,2
  expectNotSubtype("[int a], int b, List ...r, int c, [int d, int e]"); // 2,0,5,1,3,4
  expectNotSubtype("[int a], int b, List ...r, int c, [int d], int e"); // 3,0,5,1,4,2
  expectNotSubtype("[int a], int b, List ...r, int c, int d, [int e]"); // 3,0,5,1,2,4
  expectNotSubtype("[int a], int b, List ...r, int c, int d, int e"); // 4,0,5,1,2,3
  expectSubtype("int a, [int b], List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, [int b], List ...r, [int c, int d], int e"); // 0,2,5,3,4,1
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, [int e]"); // 0,2,5,3,1,4
  expectNotSubtype("int a, [int b], List ...r, [int c], int d, int e"); // 0,3,5,4,1,2
  expectNotSubtype("int a, [int b], List ...r, int c, [int d, int e]"); // 0,2,5,1,3,4
  expectNotSubtype("int a, [int b], List ...r, int c, [int d], int e"); // 0,3,5,1,4,2
  expectNotSubtype("int a, [int b], List ...r, int c, int d, [int e]"); // 0,3,5,1,2,4
  expectNotSubtype("int a, [int b], List ...r, int c, int d, int e"); // 0,4,5,1,2,3
  expectSubtype("int a, int b, List ...r, [int c, int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, [int c, int d], int e"); // 0,1,5,3,4,2
  expectNotSubtype("int a, int b, List ...r, [int c], int d, [int e]"); // 0,1,5,3,2,4
  expectNotSubtype("int a, int b, List ...r, [int c], int d, int e"); // 0,1,5,4,2,3
  expectSubtype("int a, int b, List ...r, int c, [int d, int e]"); // 0,1,5,2,3,4
  expectNotSubtype("int a, int b, List ...r, int c, [int d], int e"); // 0,1,5,2,4,3
  expectSubtype("int a, int b, List ...r, int c, int d, [int e]"); // 0,1,5,2,3,4
}
