// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_style.src.dart_formatter;

import 'dart:math' as math;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:front_end/src/fasta/parser/parser.dart' as fasta;

import 'error_listener.dart';
import 'exceptions.dart';
import 'source_code.dart';
import 'source_visitor.dart';

// DONE(semicolon): Not checking strings since dartfmt adds semicolons.
//import 'string_compare.dart' as string_compare;
import 'style_fix.dart';

/// Dart source code formatter.
class DartFormatter {
  /// The string that newlines should use.
  ///
  /// If not explicitly provided, this is inferred from the source text. If the
  /// first newline is `\r\n` (Windows), it will use that. Otherwise, it uses
  /// Unix-style line endings (`\n`).
  String lineEnding;

  /// The number of characters allowed in a single line.
  final int pageWidth;

  /// The number of characters of indentation to prefix the output lines with.
  final int indent;

  final Set<StyleFix> fixes = new Set();

  /// Creates a new formatter for Dart code.
  ///
  /// If [lineEnding] is given, that will be used for any newlines in the
  /// output. Otherwise, the line separator will be inferred from the line
  /// endings in the source file.
  ///
  /// If [indent] is given, that many levels of indentation will be prefixed
  /// before each resulting line in the output.
  ///
  /// While formatting, also applies any of the given [fixes].
  DartFormatter(
      {this.lineEnding, int pageWidth, int indent, Iterable<StyleFix> fixes})
      : pageWidth = pageWidth ?? 80,
        indent = indent ?? 0 {
    if (fixes != null) this.fixes.addAll(fixes);
  }

  /// Formats the given [source] string containing an entire Dart compilation
  /// unit.
  ///
  /// If [uri] is given, it is a [String] or [Uri] used to identify the file
  /// being formatted in error messages.
  String format(String source, {uri}) {
    if (uri == null) {
      // Do nothing.
    } else if (uri is Uri) {
      uri = uri.toString();
    } else if (uri is String) {
      // Do nothing.
    } else {
      throw new ArgumentError("uri must be `null`, a Uri, or a String.");
    }

    return formatSource(
            new SourceCode(source, uri: uri, isCompilationUnit: true))
        .text;
  }

  /// Formats the given [source] string containing a single Dart statement.
  String formatStatement(String source) {
    return formatSource(new SourceCode(source, isCompilationUnit: false)).text;
  }

  /// Formats the given [source].
  ///
  /// Returns a new [SourceCode] containing the formatted code and the resulting
  /// selection, if any.
  SourceCode formatSource(SourceCode source) {
    var errorListener = new ErrorListener();

    // Tokenize the source.
    var reader = new CharSequenceReader(source.text);
    var stringSource = new StringSource(source.text, source.uri);
    var scanner = new Scanner(stringSource, reader, errorListener);
    var startToken = scanner.tokenize();
    var lineInfo = new LineInfo(scanner.lineStarts);

    // DONE(semicolon): If optional semicolons are enabled, run the lexical
    // rules to insert implicit semicolons before parsing. Doing this here is
    // hacky, but it saves us from having to fork analyzer too for the
    // prototype.
    if (fasta.Parser.optionalSemicolons) {
      _insertSemicolons(lineInfo, startToken);
    }

    // Infer the line ending if not given one. Do it here since now we know
    // where the lines start.
    if (lineEnding == null) {
      // If the first newline is "\r\n", use that. Otherwise, use "\n".
      if (scanner.lineStarts.length > 1 &&
          scanner.lineStarts[1] >= 2 &&
          source.text[scanner.lineStarts[1] - 2] == '\r') {
        lineEnding = "\r\n";
      } else {
        lineEnding = "\n";
      }
    }

    errorListener.throwIfErrors();

    // Parse it.
    var parser = new Parser(stringSource, errorListener);
    parser.enableOptionalNewAndConst = true;

    AstNode node;
    if (source.isCompilationUnit) {
      node = parser.parseCompilationUnit(startToken);
    } else {
      node = parser.parseStatement(startToken);

      // Make sure we consumed all of the source.
      var token = node.endToken.next;
      if (token.type != TokenType.EOF) {
        var error = new AnalysisError(
            stringSource,
            token.offset,
            math.max(token.length, 1),
            ParserErrorCode.UNEXPECTED_TOKEN,
            [token.lexeme]);

        throw new FormatterException([error]);
      }
    }

    // DONE(semicolon): If optional semicolons are enabled, run the lexical
    // rules to insert implicit semicolons before parsing. Doing this here is
    // hacky, but it saves us from having to fork analyzer too for the
    // prototype.
    if (fasta.Parser.optionalSemicolons) {
      _removeImplicitSemicolons(startToken);
    }

    errorListener.throwIfErrors();

    // Format it.
    var visitor = new SourceVisitor(this, lineInfo, source);
    var output = visitor.run(node);

    // DONE(semicolon): Commenting out since dartfmt will insert semicolons.
    // Sanity check that only whitespace was changed if that's all we expect.
//    if (fixes.isEmpty &&
//        !string_compare.equalIgnoringWhitespace(source.text, output.text)) {
//      throw new UnexpectedOutputException(source.text, output.text);
//    }

    return output;
  }

  /// Don't insert a semicolon if a newline occurs after any of these tokens.
  /// These are tokens that definitely can't end an expression (or other
  /// semicolon-terminated entity). Most are infix operators.
  static final _ignoreNewlineAfter = [
    TokenType.AMPERSAND,
    TokenType.AMPERSAND_AMPERSAND,
    TokenType.AMPERSAND_AMPERSAND_EQ,
    TokenType.AMPERSAND_EQ,
    TokenType.AS,
    TokenType.BANG_EQ,
    TokenType.BANG_EQ_EQ,
    TokenType.BAR,
    TokenType.BAR_BAR,
    TokenType.BAR_BAR_EQ,
    TokenType.BAR_EQ,
    TokenType.CARET,
    TokenType.CARET_EQ,
    TokenType.COLON,
    TokenType.COMMA,
    TokenType.EQ,
    TokenType.EQ_EQ,
    TokenType.EQ_EQ_EQ,
    TokenType.FUNCTION,
    // DONE(semicolon): Can't ignore newline after this because of:
    //
    //     var a = Foo is Bar<int>
    //
    // And:
    //
    //     class Foo {
    //       factory Foo() = Bar<int>
    //     }
    // TODO(semicolon): Ignore this in grammar.
//    TokenType.GT,
    TokenType.GT_EQ,
    TokenType.GT_GT,
    TokenType.GT_GT_EQ,
    TokenType.GT_GT_GT,
    TokenType.IS,
    TokenType.LT,
    TokenType.LT_EQ,
    TokenType.LT_LT,
    TokenType.LT_LT_EQ,
    TokenType.MINUS,
    TokenType.MINUS_EQ,
    TokenType.OPEN_CURLY_BRACKET,
    TokenType.OPEN_PAREN,
    TokenType.OPEN_SQUARE_BRACKET,
    TokenType.PERCENT,
    TokenType.PERCENT_EQ,
    TokenType.PERIOD,
    TokenType.PERIOD_PERIOD,
    TokenType.PERIOD_PERIOD_PERIOD,
    TokenType.PLUS,
    TokenType.PLUS_EQ,
    // TODO(semicolon): We can't ignore a newline after "?" because of NNBD:
    //
    //     var b = o is Foo?
    TokenType.QUESTION,
    TokenType.QUESTION_PERIOD,
    TokenType.QUESTION_QUESTION,
    TokenType.QUESTION_QUESTION_EQ,
    TokenType.SCRIPT_TAG,
    TokenType.SEMICOLON,
    TokenType.SLASH,
    TokenType.SLASH_EQ,
    TokenType.STAR,
    TokenType.STAR_EQ,
    // TODO(semicolon): How are these used?
//  TokenType.STRING_INTERPOLATION_EXPRESSION,
//  TokenType.STRING_INTERPOLATION_IDENTIFIER,
    TokenType.TILDE,
    TokenType.TILDE_SLASH,
    TokenType.TILDE_SLASH_EQ,

    // Reserved words that always have something after them.
    Keyword.ASSERT,
    Keyword.CASE,
    Keyword.CATCH,
    Keyword.CLASS,
    Keyword.CONST,
    Keyword.DEFAULT,
    Keyword.DO,
    Keyword.ELSE,
    Keyword.ENUM,
    Keyword.EXTENDS,
    Keyword.FINAL,
    Keyword.FINALLY,
    Keyword.FOR,
    Keyword.IF,
    Keyword.IN,
    Keyword.IS,
    Keyword.NEW,
    Keyword.SUPER,
    Keyword.SWITCH,
    Keyword.THROW,
    Keyword.TRY,
    Keyword.VAR,
    Keyword.WHILE,
    Keyword.WITH,

// Cannot ignore newlines around built-in identifiers and contextual keywords
// because they may be used as identifiers in other contexts.
// Keyword.ABSTRACT,
// Keyword.AS,
// Keyword.ASYNC,
// Keyword.AWAIT,
// Keyword.COVARIANT,
// Keyword.DEFERRED,
// Keyword.DYNAMIC,
// Keyword.EXPORT,
// Keyword.EXTERNAL,
// Keyword.FACTORY,
// Keyword.FUNCTION,
// Keyword.GET,
// Keyword.HIDE,
// Keyword.IMPLEMENTS,
// Keyword.IMPORT,
// Keyword.INTERFACE,
// Keyword.LIBRARY,
// Keyword.MIXIN,
// Keyword.NATIVE,
// Keyword.OF,
// Keyword.ON,
// Keyword.OPERATOR,
// Keyword.PART,
// Keyword.PATCH,
// Keyword.SET,
// Keyword.SHOW,
// Keyword.SOURCE,
// Keyword.STATIC,
// Keyword.SYNC,
// Keyword.TYPEDEF,
// Keyword.YIELD,
  ].toSet();

  /// If a newline occurs before any of these tokens, we don't treat it as a
  /// semicolon. These are a subset of the tokens that definitely can't begin
  /// an expression. We are more conservative with this than with
  /// [_ignoreNewlineAfter]. We could add more to this list and that would let
  /// more Dart code with strange newlines be parsed correctly today. But:
  ///
  /// 1. We want to give ourselves room to grow the language and add new prefix
  ///    operators. Putting operators here makes it a breaking change to turn
  ///    that operator into a prefix one.
  ///
  /// 2. Idiomatic Dart rarely puts the operator on the next line, so it's less
  ///    breaking to treat a newline significant before an infix operator.
  ///
  /// 3. I think it's a more intuitive system if the rules don't do lookahead
  ///    very often.
  ///
  /// 4. It lines up with Ruby and other languages that only ignore newlines
  ///    before a few special tokens. Mainly method chains.
  static final _ignoreNewlineBefore = [
    TokenType.SEMICOLON,
    TokenType.PERIOD,
    TokenType.PERIOD_PERIOD,
    TokenType.CLOSE_PAREN,
    TokenType.CLOSE_SQUARE_BRACKET,
    // TODO(semicolon): For conditional operator. Will this interfere with
    // using "?" in prefix position later?
    TokenType.QUESTION,
    TokenType.QUESTION_PERIOD,
    // Mainly for constructor initialization lists and conditional operator.
    TokenType.COLON,

    // Dartfmt wraps before `=`.
    TokenType.EQ,

    // An expression can't start with `=>` today. Even if we later support it
    // for lambdas with no parameter lists, it's not useful to use one as a
    // statement expression, so ignore the newline before it.
    TokenType.FUNCTION,

    // Some people do like putting commas at the beginning of the line, and it's
    // unlikely we'll ever make comma prefix operator.
    TokenType.COMMA,

    // Idiomatic style puts these on the next line.
    Keyword.AS,
    Keyword.IS,

    // TODO(semicolon): Ideally we wouldn't ignore newlines before these to be
    // consistent with other operators. But the style in the Flutter repo is
    // to put these at the beginning of the line and *also* there are a decent
    // number of cases where there is a line comment by the operator, so
    // dartfmt isn't able to fix the code.
    //
    // Ignore newlines here for now to minimize spurious diffs, but we should
    // decide how we want to handle this. In practice, `&&` and `||` are
    // unlikely to ever be prefix operators, so ignoring this may be the right
    // approach.
    TokenType.AMPERSAND_AMPERSAND,
    TokenType.BAR_BAR,

    // Treat "Function" like a reserved word and ignore newlines before it.
    // DONE(semicolon): Can't do this because it can appear at the beginning
    // of a member declaration:
    //
    //     var before = value
    //     Function() returnsFunction() { ... }
//    Keyword.FUNCTION,
  ].toSet();

  void _insertSemicolons(LineInfo lineInfo, Token startToken) {
    for (var token = startToken; !token.isEof; token = token.next) {
      // Only insert if there's a newline.
      if (lineInfo.getLocation(token.previous.end).lineNumber >=
          lineInfo.getLocation(token.offset).lineNumber) {
        continue;
      }

      // Don't insert after certain tokens.
      if (_ignoreNewlineAfter.contains(token.previous.type)) continue;

      // Don't insert before certain tokens.
      if (_ignoreNewlineBefore.contains(token.type)) continue;

      // Note: This means the last statement in a block doesn't get an implicit
      // semicolon. That's OK. We change the grammar to allow "}" to mean the
      // end of a statement too in order to also handle cases like:
      //
      //     foo(() { noNewLine() })
      if (token.type == TokenType.CLOSE_CURLY_BRACKET) continue;

      // Ignore newlines between adjacent strings.
      // TODO(semicolon): This is a little dubious because it's possible to have
      // code like:
      //
      //     var a = "string"
      //     "another".someMethod()
      // Ideally, we'd get rid of adjacent strings entirely now that "+" exists,
      // but that's a difficult change. :-/
      // TODO(semicolon): Does this handle strings with interpolation in them?
      if (token.previous.type == TokenType.STRING &&
          token.type == TokenType.STRING) {
        continue;
      }

      var semicolon = Token(TokenType.SEMICOLON_IMPLICIT, token.previous.end);

      var previous = token.previous;
      semicolon.previous = previous;
      semicolon.next = token;

      previous.next = semicolon;
      token.previous = semicolon;
    }
  }

  /// After the token stream has been parsed, we no longer need any remaining
  /// implicit semicolons.
  ///
  /// These only matter because in a couple of places, dartfmt uses the token
  /// stream directly instead of pulling tokens from the AST node (which will
  /// already not be using any implicit semicolons).
  ///
  /// In particular, when outputting commas after nodes, dartfmt uses
  /// `Token.next` to find them. This makes that work correctly.
  void _removeImplicitSemicolons(Token startToken) {
    for (var token = startToken; !token.isEof; token = token.next) {
      if (token.type == TokenType.SEMICOLON_IMPLICIT) {
        var previous = token.previous;

        token.previous.next = token.next;
        token.next.previous = token.previous;

        token.next = null;
        token.previous = null;

        token = previous;
      }
    }
  }
}
