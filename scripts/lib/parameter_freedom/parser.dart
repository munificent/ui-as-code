import 'package:analyzer/dart/ast/token.dart';

import 'package:ui_as_code_tools/parser.dart';

import 'ast.dart';

class Parser {
  Token _token;

  Parser(String source) {
    _token = tokenizeString(source);
  }

  bool get isDone => _token.type == TokenType.EOF;

  ///     formalParameterList:
  ///       '(' ')' |
  ///       '(' positionalSections ')' |
  ///       '(' namedParameters ')' |
  ///       '(' positionalSections ',' namedParameters ')' |
  ///       ;
  Signature parseSignature() {
    var positional = _positionalSections();
    var named = _namedParameters();

    if (!isDone) _fail("Expected end of input.");

    return Signature(positional, named);
  }

  ///     positionalSections:
  ///       positionalSection ( ', ' positionalSection )*
  ///       ;
  ///
  ///     positionalSection:
  ///       normalFormalParameter |
  ///       restParameter |
  ///       '[' defaultFormalParameter (', ' defaultFormalParameter)* ']'
  ///       ;
  List<Parameter> _positionalSections() {
    if (isDone || _peek(TokenType.OPEN_CURLY_BRACKET)) return [];

    List<Parameter> parameters = [];
    do {
      if (_match(TokenType.OPEN_SQUARE_BRACKET)) {
        do {
          parameters.add(_parameter(isOptional: true));
        } while (_match(TokenType.COMMA));

        _expect(TokenType.CLOSE_SQUARE_BRACKET, "Expect ']' after parameters.");
      } else {
        parameters.add(_parameter(isOptional: false));
      }

      if (isDone) break;
      _expect(TokenType.COMMA, "Expect ',' after parameter.");
    } while (!_peek(TokenType.OPEN_CURLY_BRACKET));

    return parameters;
  }

  List<Parameter> _namedParameters() {
    List<Parameter> parameters = [];
    if (_match(TokenType.OPEN_CURLY_BRACKET)) {
      while (!_peek(TokenType.CLOSE_CURLY_BRACKET)) {
        parameters.add(_parameter(isOptional: false));

        if (!_match(TokenType.COMMA)) break;
      }

      _expect(TokenType.CLOSE_CURLY_BRACKET, "Expect '}'.");
    }

    return parameters;
  }

  Parameter _parameter({bool isOptional = false}) {
    // TODO: Make type optional.
    var type = _expect(TokenType.IDENTIFIER, "Expect parameter type.").lexeme;

    // TODO: "*"?
    var isRest = _match(TokenType.PERIOD_PERIOD_PERIOD);
    var name = _expect(TokenType.IDENTIFIER, "Expect parameter name.").lexeme;

    return Parameter(type, name, isRest, isOptional);
  }

  List<Argument> parseInvocation() {
    var arguments = <Argument>[];

    while (!isDone) {
      String name;
      if (_match(TokenType.IDENTIFIER, TokenType.COLON)) {
        name = _token.previous.previous.lexeme;
      }

      var value = _value();
      arguments.add(Argument(name, value));

      if (!_match(TokenType.COMMA)) break;
    }

    return arguments;
  }

  Object _value() {
    if (_match(TokenType.INT)) {
      return int.parse(_token.previous.lexeme);
    } else if (_match(TokenType.DOUBLE)) {
      return double.parse(_token.previous.lexeme);
    } else if (_matchKeyword(Keyword.NULL)) {
      return null;
    } else if (_matchKeyword(Keyword.FALSE)) {
      return false;
    } else if (_matchKeyword(Keyword.TRUE)) {
      return true;
    } else if (_match(TokenType.INDEX)) {
      return <Object>[];
    } else if (_match(TokenType.OPEN_SQUARE_BRACKET)) {
      var elements = <Object>[];
      while (_token.type != TokenType.CLOSE_SQUARE_BRACKET) {
        elements.add(_value());
        if (!_match(TokenType.COMMA)) break;
      }

      _expect(TokenType.CLOSE_SQUARE_BRACKET, "Expect ']' after list.");

      return elements;
    }

    // TODO: Literals of other types.
    _fail("Expect value.");
    return null;
  }

  bool _peek(TokenType type) => _token.type == type;

  bool _match(TokenType type, [TokenType type2]) {
    if (_token.type != type) return false;
    if (type2 != null && _token.next.type != type2) return false;

    _token = _token.next;
    if (type2 != null) _token = _token.next;
    return true;
  }

  bool _matchKeyword(Keyword keyword) {
    if (_token.keyword != keyword) return false;

    _token = _token.next;
    return true;
  }

  Token _expect(TokenType type, String error) {
    if (_token.type != type) _fail(error);

    var token = _token;
    _token = _token.next;
    return token;
  }

  void _fail(String error) {
    throw "Syntax error at '${_token.lexeme}' ${_token.offset}: $error";
  }
}
