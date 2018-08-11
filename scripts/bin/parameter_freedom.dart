// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:ui_as_code_tools/parameter_freedom/ast.dart';
import 'package:ui_as_code_tools/parameter_freedom/parser.dart';

Signature _signature;

void main(List<String> arguments) {
  signature("");
  expectSubtype("");
  expectNotSubtype("int a");
  expectSubtype("int a = 1");
  expectSubtype("List ...r");

  signature("int a, bool b, String c");
  expectSubtype("int c, bool d, String e");
  expectNotSubtype("int c, bool d, num e"); // Wrong param type.
  expectNotSubtype("int c, bool d");
  expectNotSubtype("int c, bool d, String e, num f");

  // Can add optional ones anywhere. When called through super type with only
  // three, all the optionals go away.
  expectSubtype("num f = 1, int c, num f = 1, bool d, String e");
  expectSubtype("int c, num f = 1, bool d, String e");
  expectSubtype("int c, bool d, num f = 1, String e");
  expectSubtype("int c, bool d, String e, num f = 1");
  expectSubtype("num f = 1, int c, num g = 1, num h = 1, bool d, String e, num f = 1");

  signature("int a, bool b = true, String c = null, num d");
  expectSubtype("int z, bool y = true, String x = null, num d");

  // Must maintain optionals.
  expectNotSubtype("int z, bool y, String x = null, num d");
  expectNotSubtype("int z, bool y = true, String x, num d");
  expectNotSubtype("int z, bool y, String x, num d");

  // Can add more optionals after the last.
  expectSubtype("int z, bool y = true, String x = null, bool b = false, num d, int i = 1");

  // Rests must match.
  signature("int a, List ...b, List c");
  expectSubtype("int c, List ...d, List e");
  expectNotSubtype("int c, List d, List e");
  signature("int a, List b, List c");
  expectNotSubtype("int c, List ...d, List e");

  // Can add rest param anywhere.
  signature("int a, bool b, String c");
  expectSubtype("List ...r, int a, bool b, String c");
  expectSubtype("int a, List ...r, bool b, String c");
  expectSubtype("int a, bool b, List ...r, String c");
  expectSubtype("int a, bool b, String c, List ...r");

  // Rest is not substitute for optional.
  signature("bool a, int b = 1");
  expectNotSubtype("bool a, List ...b");

  signature("bool a, List ...b");
  expectNotSubtype("bool a, int b = 1");
}

void testBinding() {
  signature("int a, int b");
  expectBind("", error: "Not enough positional arguments.");
  expectBind("3", error: "Not enough positional arguments.");
  expectBind("3, 4", binds: "a: 3, b: 4");
  expectBind("3, 4, 5", error: "Too many positional arguments.");

  expectBind("a: 3", error: "Not enough positional arguments.");
  expectBind("a: 3, b: 4", binds: "a: 3, b: 4");
  expectBind("b: 4, a: 3", binds: "a: 3, b: 4");
  expectBind("a: 3, b: 4, a: 5", error: "Bound 'a' twice.");

  signature("int a = 1, int b = 2");
  expectBind("", binds: "a: 1, b: 2");
  expectBind("3", binds: "a: 3, b: 2");
  expectBind("3, 4", binds: "a: 3, b: 4");
  expectBind("3, 4, 5", error: "Too many positional arguments.");

  signature("int a = 1, int b, int c = 2, int d, int e = 3");
  expectBind("4", error: "Not enough positional arguments.");
  expectBind("4, 5", binds: "a: 1, b: 4, c: 2, d: 5, e: 3");
  expectBind("4, 5, 6", binds: "a: 4, b: 5, c: 2, d: 6, e: 3");
  expectBind("4, 5, 6, 7", binds: "a: 4, b: 5, c: 6, d: 7, e: 3");
  expectBind("4, 5, 6, 7, 8", binds: "a: 4, b: 5, c: 6, d: 7, e: 8");

  signature("int a = 1, List ...b, int c = 2");
  expectBind("", binds: "a: 1, b: [], c: 2");
  expectBind("4", binds: "a: 4, b: [], c: 2");
  expectBind("4, 5", binds: "a: 4, b: [], c: 5");
  expectBind("4, 5, 6", binds: "a: 4, b: [5], c: 6");
  expectBind("4, 5, 6, 7", binds: "a: 4, b: [5, 6], c: 7");

  expectBind("a: 4", binds: "a: 4, b: [], c: 2");
  expectBind("b: 1", error: "Can't pass rest parameter by name.");
  expectBind("c: 4", binds: "a: 1, b: [], c: 4");
  expectBind("4, a: 5", binds: "a: 5, b: [], c: 4");
  expectBind("4, a: 5, 6", binds: "a: 5, b: [4], c: 6");

  signature("int a = 1, List ...b, int c");
  expectBind("2", binds: "a: 1, b: [], c: 2");
  expectBind("2, 3", binds: "a: 2, b: [], c: 3");
  expectBind("2, 3, 4", binds: "a: 2, b: [3], c: 4");
  expectBind("2, 3, 4, 5", binds: "a: 2, b: [3, 4], c: 5");
  expectBind("a: 2", error: "Not enough positional arguments.");
  expectBind("c: 2", binds: "a: 1, b: [], c: 2");
  expectBind("c: 2, a: 3", binds: "a: 3, b: [], c: 2");
  expectBind("2, a: 3", binds: "a: 3, b: [], c: 2");
  expectBind("2, c: 3", binds: "a: 2, b: [], c: 3");
  expectBind("2, a: 3, c: 4", binds: "a: 3, b: [2], c: 4");
  expectBind("2, a: 3, 4, c: 5, 6", binds: "a: 3, b: [2, 4, 6], c: 5");
}

void signature(String source) {
  _signature = Parser(source).parseSignature();
  print("($source)");
}

void expectBind(String invocation, {String binds, String error}) {
  var expect = <String, Object>{};
  if (binds != null) {
    for (var arg in Parser(binds).parseInvocation()) {
      expect[arg.name] = arg.value;
    }
  }

  var arguments = Parser(invocation).parseInvocation();
  var bindings = bind(arguments, _signature);

  if (bindings.containsKey("error")) {
    if (error == null) {
      print("FAIL '$invocation': Expected $expect but got error "
          "'${bindings["error"]}'.");
    } else if (error != bindings["error"]) {
      print("FAIL '$invocation': Expected error '$error' but got error "
          "'${bindings["error"]}'.");
    }

    return;
  }

  if (error != null) {
    print("FAIL '$invocation': Expected error '$error' but bound $bindings.");
  }

  var keys = expect.keys.toSet();
  keys.addAll(bindings.keys);

  var failed = false;
  for (var key in keys) {
    if (!objectsEqual(expect[key], bindings[key])) {
      print("FAIL '$invocation': Expected '$key' to be '${expect[key]}', "
          "but was '${bindings[key]}'.");
      failed = true;
    }
  }

  if (!failed) print("PASS '$invocation': $bindings");
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
      print("PASS ($other): Is subtype.");
    } else {
      print("FAIL ($other): Is not subtype and should be.");
    }
  } else {
    if (actual) {
      print("FAIL ($other): Is subtype and should not be.");
    } else {
      print("PASS ($other): Is not subtype.");
    }
  }
}

bool isSubtype(Signature a, Signature b) {
  var minArity = a.required.length;
  var maxArity = a.positional.length;

  // For every arity that the a could be called at, make sure that b at that
  // arity is a valid subtype.
  for (var arity = minArity; arity <= maxArity; arity++) {
    var aParams = atArity(a, arity);

    var bParams = atArity(b, arity);
    if (bParams == null) return false;

//    print("$arity $aParams <: $bParams");

    assert(aParams.length == bParams.length);
    for (var i = 0; i < aParams.length; i++) {
      // TODO: In a real implementation would do an actual type test.
      if (aParams[i].type != bParams[i].type) {
        return false;
      }

      // Rest param must be at same position.
      if (aParams[i].isRest != bParams[i].isRest) {
        return false;
      }
    }
  }

  return true;

  // TODO: Named.
}

/// Determines which positional parameters are used from [signature] when
/// invoked with [arity] positional arguments.
///
/// Determines which optional parameters get values bound versus using their
/// default. Also determines whether the rest parameter (if any) is used.
///
/// Returns `null` if [arity] is not valid for [signature].
List<Parameter> atArity(Signature signature, int arity) {
  // Make sure there are enough arguments for each required parameter.
  if (arity < signature.required.length) return null;

  // See how many optional parameters will get arguments.
  var optionalCount = arity - signature.required.length;

  // Make sure there aren't too many arguments.
  if (optionalCount > signature.optional.length && !signature.hasRest) {
    return null;
  }

  // See if there is at least one argument for the rest parameter.
  var hasRest = arity - signature.required.length - signature.optional.length > 0;

  // TODO: Need to check for too many?
  var result = <Parameter>[];
  for (var parameter in signature.positional) {
    if (parameter.isRequired) {
      result.add(parameter);
    } else if (parameter.isOptional && optionalCount > 0) {
      result.add(parameter);
      optionalCount--;
    } else if (hasRest) {
      assert(parameter.isRest);
      result.add(parameter);
    }
  }

  return result;
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

Map<String, Object> bind(List<Argument> invocation, Signature signature) {
  fail(String error) => {"error": error};
  // Principles:
  // - Parameter type does not affect binding.
  // - No parameter will get a positional argument if given a named one.
  // - If there are not enough positional arguments for the remaining required
  //   ones, error.
  // - If there are not enough positional arguments for all of the optional
  //   ones, they are filled in from left-to-right.

  var bindings = <String, Object>{};

  // Bind named args.
  var namedArgs = invocation.where((arg) => arg.name != null).toList();
  for (var arg in namedArgs) {
    var parameter = signature.positional
        .firstWhere((param) => param.name == arg.name, orElse: () => null);
    if (parameter == null) return fail("Unknown parameter '${arg.name}'.");

    if (parameter.isRest) return fail("Can't pass rest parameter by name.");

    if (bindings.containsKey(arg.name)) {
      return fail("Bound '${arg.name}' twice.");
    }

    bindings[arg.name] = arg.value;
  }

  // See which parameters still need to be bound using positional arguments.
  var positionalParams = signature.positional
      .where((param) => !bindings.containsKey(param.name))
      .toList();

  var positionalArgs = invocation
      .where((arg) => arg.name == null)
      .map((arg) => arg.value)
      .toList();

  var requiredParamCount =
      positionalParams.where((param) => param.isRequired).length;
  var optionalParamCount =
      positionalParams.where((param) => param.isOptional).length;

  // How many optional arguments do have a value provided.
  var providedOptionalArgCount = positionalArgs.length - requiredParamCount;

  // How many arguments are left for the rest parameter (if any).
  var providedRestArgCount =
      positionalArgs.length - requiredParamCount - optionalParamCount;

  if (requiredParamCount > positionalArgs.length) {
    return fail("Not enough positional arguments.");
  }

  if (providedRestArgCount > 0 &&
      !positionalParams.any((param) => param.isRest)) {
    return fail("Too many positional arguments.");
  }

  var argIndex = 0;
  for (var param in positionalParams) {
    if (param.isRequired) {
      // Required parameter gets value.
      bindings[param.name] = positionalArgs[argIndex++];
    } else if (param.isOptional) {
      if (providedOptionalArgCount > 0) {
        // Have an argument for this optional parameter.
        bindings[param.name] = positionalArgs[argIndex++];
        providedOptionalArgCount--;
      } else {
        // Out of arguments, use defaults.
        bindings[param.name] = param.defaultValue;
      }
    } else {
      // Rest parameter.
      if (providedRestArgCount > 0) {
        bindings[param.name] =
            positionalArgs.sublist(argIndex, argIndex + providedRestArgCount);
        argIndex += providedRestArgCount;
      } else {
        // No args left for rest.
        bindings[param.name] = [];
      }
    }
  }

  return bindings;
}
