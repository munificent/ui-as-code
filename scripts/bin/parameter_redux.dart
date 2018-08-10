// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// See ui-as-code/rejected/parameter-redux.md.
import 'package:analyzer/dart/ast/token.dart';

import 'package:ui_as_code_tools/parser.dart';

List<Parameter> _signature;

void main(List<String> arguments) {
  signature("int a, int b");
  test("", error: "Not enough positional arguments.");
  test("3", error: "Not enough positional arguments.");
  test("3, 4", binds: "a: 3, b: 4");
  test("3, 4, 5", error: "Too many positional arguments.");

  test("a: 3", error: "Not enough positional arguments.");
  test("a: 3, b: 4", binds: "a: 3, b: 4");
  test("b: 4, a: 3", binds: "a: 3, b: 4");
  test("a: 3, b: 4, a: 5", error: "Bound 'a' twice.");

  signature("int a = 1, int b = 2");
  test("", binds: "a: 1, b: 2");
  test("3", binds: "a: 3, b: 2");
  test("3, 4", binds: "a: 3, b: 4");
  test("3, 4, 5", error: "Too many positional arguments.");

  signature("int a = 1, int b, int c = 2, int d, int e = 3");
  test("4", error: "Not enough positional arguments.");
  test("4, 5", binds: "a: 1, b: 4, c: 2, d: 5, e: 3");
  test("4, 5, 6", binds: "a: 4, b: 5, c: 2, d: 6, e: 3");
  test("4, 5, 6, 7", binds: "a: 4, b: 5, c: 6, d: 7, e: 3");
  test("4, 5, 6, 7, 8", binds: "a: 4, b: 5, c: 6, d: 7, e: 8");

  signature("int a = 1, List ...b, int c = 2");
  test("", binds: "a: 1, b: [], c: 2");
  test("4", binds: "a: 4, b: [], c: 2");
  test("4, 5", binds: "a: 4, b: [], c: 5");
  test("4, 5, 6", binds: "a: 4, b: [5], c: 6");
  test("4, 5, 6, 7", binds: "a: 4, b: [5, 6], c: 7");

  test("a: 4", binds: "a: 4, b: [], c: 2");
  test("b: 1", error: "Can't pass rest parameter by name.");
  test("c: 4", binds: "a: 1, b: [], c: 4");
  test("4, a: 5", binds: "a: 5, b: [], c: 4");
  test("4, a: 5, 6", binds: "a: 5, b: [4], c: 6");

  signature("int a = 1, List ...b, int c");
  test("2", binds: "a: 1, b: [], c: 2");
  test("2, 3", binds: "a: 2, b: [], c: 3");
  test("2, 3, 4", binds: "a: 2, b: [3], c: 4");
  test("2, 3, 4, 5", binds: "a: 2, b: [3, 4], c: 5");
  test("a: 2", error: "Not enough positional arguments.");
  test("c: 2", binds: "a: 1, b: [], c: 2");
  test("c: 2, a: 3", binds: "a: 3, b: [], c: 2");
  test("2, a: 3", binds: "a: 3, b: [], c: 2");
  test("2, c: 3", binds: "a: 2, b: [], c: 3");
  test("2, a: 3, c: 4", binds: "a: 3, b: [2], c: 4");
  test("2, a: 3, 4, c: 5, 6", binds: "a: 3, b: [2, 4, 6], c: 5");
}

void signature(String source) {
  _signature = Parser(source).parseSignature();
  print("($source)");
}

void test(String invocation, {String binds, String error}) {
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

  if (failed) print(expect);

  if (!failed) print("PASS '$invocation': $bindings");
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

Map<String, Object> bind(List<Argument> invocation, List<Parameter> signature) {
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
    var parameter = signature.firstWhere((param) => param.name == arg.name,
        orElse: () => null);
    if (parameter == null) return fail("Unknown parameter '${arg.name}'.");

    if (parameter.isRest) return fail("Can't pass rest parameter by name.");

    if (bindings.containsKey(arg.name)) {
      return fail("Bound '${arg.name}' twice.");
    }

    bindings[arg.name] = arg.value;
  }

  // See which parameters still need to be bound using positional arguments.
  var positionalParams =
      signature.where((param) => !bindings.containsKey(param.name)).toList();

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

  if (providedRestArgCount > 0 && !positionalParams.any((param) => param.isRest)) {
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

class Parameter {
  /// May be null. Would be actual type in real implementation.
  final String type;

  /// Only one parameter in a signature can set this.
  final bool isRest;

  final String name;

  /// Optional. Using "null" to indicate "no default value". A real
  /// implementation would allow "null" as an explicit default which is
  /// different from no detault.
  final Object defaultValue;

  bool get isRequired => defaultValue == null && !isRest;

  bool get isOptional => defaultValue != null && !isRest;

  Parameter(this.type, this.isRest, this.name, this.defaultValue);

  String toString() {
    var result = "";
    if (type != null) result = "$type ";

    if (isRest) result += "...";
    result += name;

    if (defaultValue != null) result += " = $defaultValue";

    return result;
  }
}

class Argument {
  /// Optional. Null if positional argument.
  final String name;

  final Object value;

  Argument(this.name, this.value);

  String toString() {
    var result = "";
    if (name != null) result = "$name: ";
    return "$result$value";
  }
}

class Parser {
  Token _token;

  Parser(String source) {
    _token = tokenizeString(source);
  }

  bool get isDone => _token.type == TokenType.EOF;

  List<Parameter> parseSignature() {
    var parameters = <Parameter>[];

    while (!isDone) {
      // TODO: Make type optional.
      var type = expect(TokenType.IDENTIFIER, "Expect parameter type.").lexeme;

      var isRest = match(TokenType.PERIOD_PERIOD_PERIOD);
      var name = expect(TokenType.IDENTIFIER, "Expect parameter name.").lexeme;

      Object defaultValue;
      if (match(TokenType.EQ)) defaultValue = parseValue();

      parameters.add(Parameter(type, isRest, name, defaultValue));

      if (!match(TokenType.COMMA)) break;
    }

    return parameters;
  }

  List<Argument> parseInvocation() {
    var arguments = <Argument>[];

    while (!isDone) {
      String name;
      if (match(TokenType.IDENTIFIER, TokenType.COLON)) {
        name = _token.previous.previous.lexeme;
      }

      var value = parseValue();
      arguments.add(Argument(name, value));

      if (!match(TokenType.COMMA)) break;
    }

    return arguments;
  }

  Object parseValue() {
    if (match(TokenType.INT)) {
      return int.parse(_token.previous.lexeme);
    } else if (match(TokenType.DOUBLE)) {
      return double.parse(_token.previous.lexeme);
    } else if (match(TokenType.IDENTIFIER)) {
      if (_token.previous.keyword == Keyword.FALSE) return false;
      if (_token.previous.keyword == Keyword.TRUE) return true;
    } else if (match(TokenType.INDEX)) {
      return <Object>[];
    } else if (match(TokenType.OPEN_SQUARE_BRACKET)) {
      var elements = <Object>[];
      while (_token.type != TokenType.CLOSE_SQUARE_BRACKET) {
        elements.add(parseValue());
        if (!match(TokenType.COMMA)) break;
      }

      expect(TokenType.CLOSE_SQUARE_BRACKET, "Expect ']' after list.");

      return elements;
    }

    // TODO: Literals of other types.
    _fail("Expect value.");
    return null;
  }

  bool match(TokenType type, [TokenType type2]) {
    if (_token.type != type) return false;
    if (type2 != null && _token.next.type != type2) return false;

    _token = _token.next;
    if (type2 != null) _token = _token.next;
    return true;
  }

  Token expect(TokenType type, String error) {
    if (_token.type != type) _fail(error);

    var token = _token;
    _token = _token.next;
    return token;
  }

  void _fail(String error) {
    throw "Syntax error at '${_token.lexeme}' ${_token.offset}: $error";
  }
}
