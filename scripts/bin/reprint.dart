// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:path/path.dart' as p;
import 'package:ui_as_code_tools/parser.dart';

/// Pretty-prints Dart source files.
void main(List<String> arguments) {
  forEachDartFile(arguments[0], includeTests: true, callback: (file, relative) {
    if (arguments.length > 1) {
      print(relative);
    }

    var errorListener = new ErrorListener();

    var source = file.readAsStringSync();
    var reader = new CharSequenceReader(source);
    var stringSource = new StringSource(source, relative);
    var scanner = new Scanner(stringSource, reader, errorListener);
    var token = scanner.tokenize();

    var parser = new Parser(stringSource, errorListener);
    parser.enableOptionalNewAndConst = true;

    var node = parser.parseCompilationUnit(token);

    if (errorListener.hadError) {
      // Just copy over the file so that we don't see spurious diffs from
      // erroneous files.
      if (arguments.length > 1) {
        var outPath = p.join(arguments[1], relative);
        new Directory(p.dirname(outPath)).createSync(recursive: true);
        new File(outPath).writeAsStringSync(source);
      }
    } else {
      var buffer = new StringBuffer();
      new ReprintVisitor(source, buffer).visit(node);

      if (arguments.length > 1) {
        var outPath = p.join(arguments[1], relative);
        new Directory(p.dirname(outPath)).createSync(recursive: true);
        new File(outPath).writeAsStringSync(buffer.toString());
      } else {
        print("⟨" + source.replaceAll(" ", "·") + "⟩");
        print("---");
        print("⟨" + buffer.toString().replaceAll(" ", "·") + "⟩");
      }
    }
  });
}

/// Takes an AST and outputs a string that should be identical to the original
/// parsed source.
///
/// This probably seems pointless, but it lets us make targeted tweaks to the
/// output string taking into account the grammatical context where it occurs.
/// For example, we could change the "{" and "}" in map literals to some other
/// character without affecting other curly braces.
///
/// Copied from analyzer's ToSourceVisitor2.
class ReprintVisitor implements AstVisitor<Object> {
  final String _source;
  final StringBuffer _buffer;

  StackTrace lastComma;

  ReprintVisitor(this._source, this._buffer);

  void visit(CompilationUnit node) {
    node.accept(this);

    // Write whitespace and comments after last (eof) token.
    if (node.endToken.previous.end != -1) {
      _buffer.write(_source.substring(node.endToken.previous.end));
    } else if (node.beginToken.type == TokenType.EOF) {
      // The entire file is empty (except for comments and whitespace), so just
      // write it.
      _buffer.write(_source);
    }
  }

  void writeToken(Token token) {
    if (token == null) return;

    // Include preceding whitespace and comments.
    var start = token.previous.end;
    if (start == -1) start = 0;
    _buffer.write(_source.substring(start, token.offset));

    _buffer.write(token.lexeme);
  }

  /// Note: This should only be used for "simple" nodes where we don't care
  /// about its individual tokens.
  writeNode(AstNode node) {
    if (node == null) return;

    // Include preceding whitespace and comments.
    var start = node.beginToken.previous.end;
    if (start == -1) start = 0;
    _buffer.write(_source.substring(start, node.endToken.end));
  }

  void writeCommaAfter(AstNode node) {
    if (node == null) return;
    if (node.endToken.next.lexeme != ",") return;
    writeToken(node.endToken.next);
  }

  /**
   * Safely visit the given [node].
   */
  void safelyVisitNode(AstNode node) {
    if (node != null) {
      node.accept(this);
    }
  }

  void writeNodeList(NodeList<AstNode> nodes, {bool commas = false}) {
    if (nodes == null) return;

    int size = nodes.length;
    for (int i = 0; i < size; i++) {
      var node = nodes[i];
      node.accept(this);
      if (commas) writeCommaAfter(node);
    }
  }

  @override
  Object visitAdjacentStrings(AdjacentStrings node) {
    writeNodeList(node.strings);
    return null;
  }

  @override
  Object visitAnnotation(Annotation node) {
    writeToken(node.atSign);
    safelyVisitNode(node.name);
    writeToken(node.period);
    safelyVisitNode(node.constructorName);
    safelyVisitNode(node.arguments);
    return null;
  }

  @override
  Object visitArgumentList(ArgumentList node) {
    writeToken(node.leftParenthesis);
    writeNodeList(node.arguments, commas: true);
    writeToken(node.rightParenthesis);
    return null;
  }

  @override
  Object visitAsExpression(AsExpression node) {
    safelyVisitNode(node.expression);
    writeToken(node.asOperator);
    safelyVisitNode(node.type);
    return null;
  }

  @override
  bool visitAssertInitializer(AssertInitializer node) {
    writeToken(node.assertKeyword);
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.condition);
    writeToken(node.comma);
    safelyVisitNode(node.message);
    writeCommaAfter(node.message ?? node.condition);
    writeToken(node.rightParenthesis);
    return null;
  }

  @override
  Object visitAssertStatement(AssertStatement node) {
    writeToken(node.assertKeyword);
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.condition);
    writeToken(node.comma);
    safelyVisitNode(node.message);
    writeCommaAfter(node.message ?? node.condition);
    writeToken(node.rightParenthesis);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitAssignmentExpression(AssignmentExpression node) {
    safelyVisitNode(node.leftHandSide);
    writeToken(node.operator);
    safelyVisitNode(node.rightHandSide);
    return null;
  }

  @override
  Object visitAwaitExpression(AwaitExpression node) {
    writeToken(node.awaitKeyword);
    safelyVisitNode(node.expression);
    return null;
  }

  @override
  Object visitBinaryExpression(BinaryExpression node) {
    node.leftOperand.accept(this);
    writeToken(node.operator);
    node.rightOperand.accept(this);
    return null;
  }

  @override
  Object visitBlock(Block node) {
    writeToken(node.leftBracket);
    writeNodeList(node.statements);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitBlockFunctionBody(BlockFunctionBody node) {
    writeToken(node.keyword);
    writeToken(node.star);
    safelyVisitNode(node.block);
    return null;
  }

  @override
  Object visitBooleanLiteral(BooleanLiteral node) {
    writeToken(node.literal);
    return null;
  }

  @override
  Object visitBreakStatement(BreakStatement node) {
    writeToken(node.breakKeyword);
    safelyVisitNode(node.label);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitCascadeExpression(CascadeExpression node) {
    safelyVisitNode(node.target);
    writeNodeList(node.cascadeSections);
    return null;
  }

  @override
  Object visitCatchClause(CatchClause node) {
    writeToken(node.onKeyword);
    safelyVisitNode(node.exceptionType);
    writeToken(node.catchKeyword);
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.exceptionParameter);
    writeToken(node.comma);
    safelyVisitNode(node.stackTraceParameter);
    writeToken(node.rightParenthesis);
    safelyVisitNode(node.body);
    return null;
  }

  @override
  Object visitClassDeclaration(ClassDeclaration node) {
    writeNodeList(node.metadata);
    writeToken(node.abstractKeyword);
    writeToken(node.classKeyword);
    safelyVisitNode(node.name);
    safelyVisitNode(node.typeParameters);
    safelyVisitNode(node.extendsClause);
    safelyVisitNode(node.withClause);
    safelyVisitNode(node.implementsClause);
    writeToken(node.leftBracket);
    writeNodeList(node.members);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitClassTypeAlias(ClassTypeAlias node) {
    writeNodeList(node.metadata);
    writeToken(node.abstractKeyword);
    writeToken(node.typedefKeyword); // TODO(bob): Is this right? Was "class".
    safelyVisitNode(node.name);
    safelyVisitNode(node.typeParameters);
    writeToken(node.equals);
    safelyVisitNode(node.superclass);
    safelyVisitNode(node.withClause);
    safelyVisitNode(node.implementsClause);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitComment(Comment node) => null;

  @override
  Object visitCommentReference(CommentReference node) => null;

  @override
  Object visitCompilationUnit(CompilationUnit node) {
    safelyVisitNode(node.scriptTag);
    writeNodeList(node.directives);
    writeNodeList(node.declarations);
    return null;
  }

  @override
  Object visitConditionalExpression(ConditionalExpression node) {
    safelyVisitNode(node.condition);
    writeToken(node.question);
    safelyVisitNode(node.thenExpression);
    writeToken(node.colon);
    safelyVisitNode(node.elseExpression);
    return null;
  }

  @override
  Object visitConfiguration(Configuration node) {
    writeToken(node.ifKeyword);
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.name);
    writeToken(node.equalToken);
    safelyVisitNode(node.value);
    writeToken(node.rightParenthesis);
    safelyVisitNode(node.uri);
    return null;
  }

  @override
  Object visitConstructorDeclaration(ConstructorDeclaration node) {
    writeNodeList(node.metadata);
    writeToken(node.externalKeyword);
    writeToken(node.constKeyword);
    writeToken(node.factoryKeyword);
    safelyVisitNode(node.returnType);
    writeToken(node.period);
    safelyVisitNode(node.name);
    safelyVisitNode(node.parameters);
    writeToken(node.separator);
    writeNodeList(node.initializers, commas: true);
    safelyVisitNode(node.redirectedConstructor);
    safelyVisitNode(node.body);
    return null;
  }

  @override
  Object visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    writeToken(node.thisKeyword);
    writeToken(node.period);
    safelyVisitNode(node.fieldName);
    writeToken(node.equals);
    safelyVisitNode(node.expression);
    return null;
  }

  @override
  Object visitConstructorName(ConstructorName node) {
    safelyVisitNode(node.type);
    writeToken(node.period);
    safelyVisitNode(node.name);
    return null;
  }

  @override
  Object visitContinueStatement(ContinueStatement node) {
    writeToken(node.continueKeyword);
    safelyVisitNode(node.label);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitDeclaredIdentifier(DeclaredIdentifier node) {
    writeNodeList(node.metadata);
    writeToken(node.keyword);
    safelyVisitNode(node.type);
    safelyVisitNode(node.identifier);
    return null;
  }

  @override
  Object visitDefaultFormalParameter(DefaultFormalParameter node) {
    safelyVisitNode(node.parameter);
    writeToken(node.separator);
    safelyVisitNode(node.defaultValue);
    return null;
  }

  @override
  Object visitDoStatement(DoStatement node) {
    writeToken(node.doKeyword);
    safelyVisitNode(node.body);
    writeToken(node.whileKeyword);
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.condition);
    writeToken(node.rightParenthesis);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitDottedName(DottedName node) {
    for (var i = 0; i < node.components.length; i++) {
      var component = node.components[i];
      if (i > 0) {
        // ".".
        writeToken(component.beginToken.previous);
      }
      component.accept(this);
    }

    return null;
  }

  @override
  Object visitDoubleLiteral(DoubleLiteral node) {
    writeToken(node.literal);
    return null;
  }

  @override
  Object visitEmptyFunctionBody(EmptyFunctionBody node) {
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitEmptyStatement(EmptyStatement node) {
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    writeNodeList(node.metadata);
    safelyVisitNode(node.name);
    return null;
  }

  @override
  Object visitEnumDeclaration(EnumDeclaration node) {
    writeNodeList(node.metadata);
    writeToken(node.enumKeyword);
    safelyVisitNode(node.name);
    writeToken(node.leftBracket);
    writeNodeList(node.constants, commas: true);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitExportDirective(ExportDirective node) {
    writeNodeList(node.metadata);
    writeToken(node.keyword);
    safelyVisitNode(node.uri);
    writeNodeList(node.configurations);
    writeNodeList(node.combinators);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitExpressionFunctionBody(ExpressionFunctionBody node) {
    writeToken(node.keyword);
    writeToken(node.functionDefinition);
    safelyVisitNode(node.expression);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitExpressionStatement(ExpressionStatement node) {
    safelyVisitNode(node.expression);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitExtendsClause(ExtendsClause node) {
    writeToken(node.extendsKeyword);
    safelyVisitNode(node.superclass);
    return null;
  }

  @override
  Object visitFieldDeclaration(FieldDeclaration node) {
    writeNodeList(node.metadata);
    writeToken(node.covariantKeyword);
    writeToken(node.staticKeyword);
    safelyVisitNode(node.fields);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitFieldFormalParameter(FieldFormalParameter node) {
    writeNodeList(node.metadata);
    writeToken(node.covariantKeyword);
    writeToken(node.keyword);
    safelyVisitNode(node.type);
    writeToken(node.thisKeyword);
    writeToken(node.period);
    safelyVisitNode(node.identifier);
    safelyVisitNode(node.typeParameters);
    safelyVisitNode(node.parameters);
    return null;
  }

  @override
  Object visitForEachStatement(ForEachStatement node) {
    writeToken(node.awaitKeyword);
    writeToken(node.forKeyword);
    writeToken(node.leftParenthesis);

    if (node.loopVariable == null) {
      safelyVisitNode(node.identifier);
    } else {
      safelyVisitNode(node.loopVariable);
    }

    writeToken(node.inKeyword);
    safelyVisitNode(node.iterable);
    writeToken(node.rightParenthesis);
    safelyVisitNode(node.body);
    return null;
  }

  @override
  Object visitFormalParameterList(FormalParameterList node) {
    writeToken(node.leftParenthesis);
    NodeList<FormalParameter> parameters = node.parameters;
    int size = parameters.length;
    for (int i = 0; i < size; i++) {
      FormalParameter parameter = parameters[i];

      if (parameter is DefaultFormalParameter &&
          (i == 0 || parameters[i - 1] is! DefaultFormalParameter)) {
        writeToken(node.leftDelimiter);
      }

      parameter.accept(this);
      writeCommaAfter(parameter);
    }

    writeToken(node.rightDelimiter);
    writeToken(node.rightParenthesis);
    return null;
  }

  @override
  Object visitForStatement(ForStatement node) {
    Expression initialization = node.initialization;
    writeToken(node.forKeyword);
    writeToken(node.leftParenthesis);
    if (initialization != null) {
      safelyVisitNode(initialization);
    } else {
      safelyVisitNode(node.variables);
    }
    writeToken(node.leftSeparator);
    safelyVisitNode(node.condition);
    writeToken(node.rightSeparator);
    writeNodeList(node.updaters, commas: true);
    writeToken(node.rightParenthesis);
    safelyVisitNode(node.body);
    return null;
  }

  @override
  Object visitFunctionDeclaration(FunctionDeclaration node) {
    writeNodeList(node.metadata);
    writeToken(node.externalKeyword);
    safelyVisitNode(node.returnType);
    writeToken(node.propertyKeyword);
    safelyVisitNode(node.name);
    safelyVisitNode(node.functionExpression);
    return null;
  }

  @override
  Object visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    safelyVisitNode(node.functionDeclaration);
    return null;
  }

  @override
  Object visitFunctionExpression(FunctionExpression node) {
    safelyVisitNode(node.typeParameters);
    safelyVisitNode(node.parameters);
    safelyVisitNode(node.body);
    return null;
  }

  @override
  Object visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    safelyVisitNode(node.function);
    safelyVisitNode(node.typeArguments);
    safelyVisitNode(node.argumentList);
    return null;
  }

  @override
  Object visitFunctionTypeAlias(FunctionTypeAlias node) {
    writeNodeList(node.metadata);
    writeToken(node.typedefKeyword);
    safelyVisitNode(node.returnType);
    safelyVisitNode(node.name);
    safelyVisitNode(node.typeParameters);
    safelyVisitNode(node.parameters);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    writeNodeList(node.metadata);
    writeToken(node.covariantKeyword);
    safelyVisitNode(node.returnType);
    safelyVisitNode(node.identifier);
    safelyVisitNode(node.typeParameters);
    safelyVisitNode(node.parameters);
    return null;
  }

  @override
  Object visitGenericFunctionType(GenericFunctionType node) {
    safelyVisitNode(node.returnType);
    writeToken(node.functionKeyword);
    safelyVisitNode(node.typeParameters);
    safelyVisitNode(node.parameters);
    return null;
  }

  @override
  Object visitGenericTypeAlias(GenericTypeAlias node) {
    writeNodeList(node.metadata);
    writeToken(node.typedefKeyword);
    safelyVisitNode(node.name);
    safelyVisitNode(node.typeParameters);
    writeToken(node.equals);
    safelyVisitNode(node.functionType);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitHideCombinator(HideCombinator node) {
    writeToken(node.keyword);
    writeNodeList(node.hiddenNames, commas: true);
    return null;
  }

  @override
  Object visitIfStatement(IfStatement node) {
    writeToken(node.ifKeyword);
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.condition);
    writeToken(node.rightParenthesis);
    safelyVisitNode(node.thenStatement);
    writeToken(node.elseKeyword);
    safelyVisitNode(node.elseStatement);
    return null;
  }

  @override
  Object visitImplementsClause(ImplementsClause node) {
    writeToken(node.implementsKeyword);
    writeNodeList(node.interfaces, commas: true);
    return null;
  }

  @override
  Object visitImportDirective(ImportDirective node) {
    writeNodeList(node.metadata);
    writeToken(node.keyword);
    safelyVisitNode(node.uri);
    writeNodeList(node.configurations);
    writeToken(node.deferredKeyword);
    writeToken(node.asKeyword);
    safelyVisitNode(node.prefix);
    writeNodeList(node.combinators);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitIndexExpression(IndexExpression node) {
    if (node.isCascaded) {
      writeToken(node.period);
    } else {
      safelyVisitNode(node.target);
    }
    writeToken(node.leftBracket);
    safelyVisitNode(node.index);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitInstanceCreationExpression(InstanceCreationExpression node) {
    writeToken(node.keyword);
    safelyVisitNode(node.constructorName);
    safelyVisitNode(node.argumentList);
    return null;
  }

  @override
  Object visitIntegerLiteral(IntegerLiteral node) {
    writeToken(node.literal);
    return null;
  }

  @override
  Object visitInterpolationExpression(InterpolationExpression node) {
    if (node.rightBracket != null) {
      writeToken(node.leftBracket);
      safelyVisitNode(node.expression);
      writeToken(node.rightBracket);
    } else {
      writeToken(node.leftBracket);
      safelyVisitNode(node.expression);
    }
    return null;
  }

  @override
  Object visitInterpolationString(InterpolationString node) {
    writeToken(node.contents);
    return null;
  }

  @override
  Object visitIsExpression(IsExpression node) {
    safelyVisitNode(node.expression);
    writeToken(node.isOperator);
    writeToken(node.notOperator);
    safelyVisitNode(node.type);
    return null;
  }

  @override
  Object visitLabel(Label node) {
    safelyVisitNode(node.label);
    writeToken(node.colon);
    return null;
  }

  @override
  Object visitLabeledStatement(LabeledStatement node) {
    writeNodeList(node.labels);
    safelyVisitNode(node.statement);
    return null;
  }

  @override
  Object visitLibraryDirective(LibraryDirective node) {
    writeNodeList(node.metadata);
    writeToken(node.keyword);
    safelyVisitNode(node.name);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitLibraryIdentifier(LibraryIdentifier node) {
    writeNode(node);
    return null;
  }

  @override
  Object visitListLiteral(ListLiteral node) {
    writeToken(node.constKeyword);
    safelyVisitNode(node.typeArguments);
    writeToken(node.leftBracket);
    writeNodeList(node.elements, commas: true);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitMapLiteral(MapLiteral node) {
    writeToken(node.constKeyword);
    safelyVisitNode(node.typeArguments);
    writeToken(node.leftBracket);
    writeNodeList(node.entries, commas: true);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitMapLiteralEntry(MapLiteralEntry node) {
    safelyVisitNode(node.key);
    writeToken(node.separator);
    safelyVisitNode(node.value);
    return null;
  }

  @override
  Object visitMethodDeclaration(MethodDeclaration node) {
    writeNodeList(node.metadata);
    writeToken(node.externalKeyword);
    writeToken(node.modifierKeyword);
    safelyVisitNode(node.returnType);
    writeToken(node.propertyKeyword);
    writeToken(node.operatorKeyword);
    safelyVisitNode(node.name);
    if (!node.isGetter) {
      safelyVisitNode(node.typeParameters);
      safelyVisitNode(node.parameters);
    }
    safelyVisitNode(node.body);
    return null;
  }

  @override
  Object visitMethodInvocation(MethodInvocation node) {
    if (node.isCascaded) {
      writeToken(node.operator);
    } else {
      if (node.target != null) {
        node.target.accept(this);
        writeToken(node.operator);
      }
    }
    safelyVisitNode(node.methodName);
    safelyVisitNode(node.typeArguments);
    safelyVisitNode(node.argumentList);
    return null;
  }

  @override
  bool visitMixinDeclaration(MixinDeclaration node) {
    writeNodeList(node.metadata);
    writeToken(node.mixinKeyword);
    safelyVisitNode(node.name);
    safelyVisitNode(node.typeParameters);
    safelyVisitNode(node.onClause);
    safelyVisitNode(node.implementsClause);
    writeToken(node.leftBracket);
    writeNodeList(node.members);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitNamedExpression(NamedExpression node) {
    safelyVisitNode(node.name);
    safelyVisitNode(node.expression);
    return null;
  }

  @override
  Object visitNativeClause(NativeClause node) {
    writeToken(node.nativeKeyword);
    safelyVisitNode(node.name);
    return null;
  }

  @override
  Object visitNativeFunctionBody(NativeFunctionBody node) {
    writeToken(node.nativeKeyword);
    safelyVisitNode(node.stringLiteral);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitNullLiteral(NullLiteral node) {
    writeToken(node.literal);
    return null;
  }

  @override
  bool visitOnClause(OnClause node) {
    writeToken(node.onKeyword);
    writeNodeList(node.superclassConstraints, commas: true);
    return null;
  }

  @override
  Object visitParenthesizedExpression(ParenthesizedExpression node) {
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.expression);
    writeToken(node.rightParenthesis);
    return null;
  }

  @override
  Object visitPartDirective(PartDirective node) {
    writeNodeList(node.metadata);
    writeToken(node.partKeyword);
    safelyVisitNode(node.uri);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitPartOfDirective(PartOfDirective node) {
    writeNodeList(node.metadata);
    writeToken(node.partKeyword);
    writeToken(node.ofKeyword);
    safelyVisitNode(node.uri);
    safelyVisitNode(node.libraryName);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitPostfixExpression(PostfixExpression node) {
    node.operand.accept(this);
    writeToken(node.operator);
    return null;
  }

  @override
  Object visitPrefixedIdentifier(PrefixedIdentifier node) {
    safelyVisitNode(node.prefix);
    writeToken(node.period);
    safelyVisitNode(node.identifier);
    return null;
  }

  @override
  Object visitPrefixExpression(PrefixExpression node) {
    writeToken(node.operator);
    node.operand.accept(this);
    return null;
  }

  @override
  Object visitPropertyAccess(PropertyAccess node) {
    if (node.isCascaded) {
      writeToken(node.operator);
    } else {
      safelyVisitNode(node.target);
      writeToken(node.operator);
    }
    safelyVisitNode(node.propertyName);
    return null;
  }

  @override
  Object visitRedirectingConstructorInvocation(
      RedirectingConstructorInvocation node) {
    writeToken(node.thisKeyword);
    writeToken(node.period);
    safelyVisitNode(node.constructorName);
    safelyVisitNode(node.argumentList);
    return null;
  }

  @override
  Object visitRethrowExpression(RethrowExpression node) {
    writeToken(node.rethrowKeyword);
    return null;
  }

  @override
  Object visitReturnStatement(ReturnStatement node) {
    writeToken(node.returnKeyword);
    safelyVisitNode(node.expression);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitScriptTag(ScriptTag node) {
    writeToken(node.scriptTag);
    return null;
  }

  @override
  Object visitShowCombinator(ShowCombinator node) {
    writeToken(node.keyword);
    writeNodeList(node.shownNames, commas: true);
    return null;
  }

  @override
  Object visitSimpleFormalParameter(SimpleFormalParameter node) {
    writeNodeList(node.metadata);
    writeToken(node.covariantKeyword);
    writeToken(node.keyword);
    safelyVisitNode(node.type);
    safelyVisitNode(node.identifier);
    return null;
  }

  @override
  Object visitSimpleIdentifier(SimpleIdentifier node) {
    writeToken(node.token);
    return null;
  }

  @override
  Object visitSimpleStringLiteral(SimpleStringLiteral node) {
    writeToken(node.literal);
    return null;
  }

  @override
  Object visitStringInterpolation(StringInterpolation node) {
    writeNodeList(node.elements);
    return null;
  }

  @override
  Object visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    writeToken(node.superKeyword);
    writeToken(node.period);
    safelyVisitNode(node.constructorName);
    safelyVisitNode(node.argumentList);
    return null;
  }

  @override
  Object visitSuperExpression(SuperExpression node) {
    writeToken(node.superKeyword);
    return null;
  }

  @override
  Object visitSwitchCase(SwitchCase node) {
    writeNodeList(node.labels);
    writeToken(node.keyword);
    safelyVisitNode(node.expression);
    writeToken(node.colon);
    writeNodeList(node.statements);
    return null;
  }

  @override
  Object visitSwitchDefault(SwitchDefault node) {
    writeNodeList(node.labels);
    writeToken(node.keyword);
    writeToken(node.colon);
    writeNodeList(node.statements);
    return null;
  }

  @override
  Object visitSwitchStatement(SwitchStatement node) {
    writeToken(node.switchKeyword);
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.expression);
    writeToken(node.rightParenthesis);
    writeToken(node.leftBracket);
    writeNodeList(node.members);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitSymbolLiteral(SymbolLiteral node) {
    writeToken(node.poundSign);
    for (var i = 0; i < node.components.length; i++) {
      var component = node.components[i];
      if (i > 0) {
        // ".".
        writeToken(component.previous);
      }
      writeToken(component);
    }

    return null;
  }

  @override
  Object visitThisExpression(ThisExpression node) {
    writeToken(node.thisKeyword);
    return null;
  }

  @override
  Object visitThrowExpression(ThrowExpression node) {
    writeToken(node.throwKeyword);
    safelyVisitNode(node.expression);
    return null;
  }

  @override
  Object visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    writeNodeList(node.metadata);
    safelyVisitNode(node.variables);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitTryStatement(TryStatement node) {
    writeToken(node.tryKeyword);
    safelyVisitNode(node.body);
    writeNodeList(node.catchClauses);
    writeToken(node.finallyKeyword);
    safelyVisitNode(node.finallyBlock);
    return null;
  }

  @override
  Object visitTypeArgumentList(TypeArgumentList node) {
    writeToken(node.leftBracket);
    writeNodeList(node.arguments, commas: true);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitTypeName(TypeName node) {
    safelyVisitNode(node.name);
    safelyVisitNode(node.typeArguments);
    return null;
  }

  @override
  Object visitTypeParameter(TypeParameter node) {
    writeNodeList(node.metadata);
    safelyVisitNode(node.name);
    writeToken(node.extendsKeyword);
    safelyVisitNode(node.bound);
    return null;
  }

  @override
  Object visitTypeParameterList(TypeParameterList node) {
    writeToken(node.leftBracket);
    writeNodeList(node.typeParameters, commas: true);
    writeToken(node.rightBracket);
    return null;
  }

  @override
  Object visitVariableDeclaration(VariableDeclaration node) {
    writeNodeList(node.metadata);
    safelyVisitNode(node.name);
    writeToken(node.equals);
    safelyVisitNode(node.initializer);
    return null;
  }

  @override
  Object visitVariableDeclarationList(VariableDeclarationList node) {
    writeNodeList(node.metadata);
    writeToken(node.keyword);
    safelyVisitNode(node.type);
    writeNodeList(node.variables, commas: true);
    return null;
  }

  @override
  Object visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    safelyVisitNode(node.variables);
    writeToken(node.semicolon);
    return null;
  }

  @override
  Object visitWhileStatement(WhileStatement node) {
    writeToken(node.whileKeyword);
    writeToken(node.leftParenthesis);
    safelyVisitNode(node.condition);
    writeToken(node.rightParenthesis);
    safelyVisitNode(node.body);
    return null;
  }

  @override
  Object visitWithClause(WithClause node) {
    writeToken(node.withKeyword);
    writeNodeList(node.mixinTypes, commas: true);
    return null;
  }

  @override
  Object visitYieldStatement(YieldStatement node) {
    writeToken(node.yieldKeyword);
    writeToken(node.star);
    safelyVisitNode(node.expression);
    writeToken(node.semicolon);
    return null;
  }
}
