// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This library exports all API from Kernel's ast.dart that can be used
/// throughout fasta.
library fasta.kernel_ast_api;

export 'package:kernel/ast.dart'
    show
        Arguments,
        AsExpression,
        AssertStatement,
        AsyncMarker,
        Block,
        BottomType,
        BreakStatement,
        Catch,
        CheckLibraryIsLoaded,
        Class,
        Constructor,
        ConstructorInvocation,
        ContinueSwitchStatement,
        DartType,
        DynamicType,
        EmptyStatement,
        Expression,
        ExpressionStatement,
        Field,
        FunctionDeclaration,
        FunctionExpression,
        FunctionNode,
        FunctionType,
        Initializer,
        InterfaceType,
        InvalidExpression,
        InvalidType,
        IsExpression,
        LabeledStatement,
        Let,
        Library,
        LibraryDependency,
        LibraryPart,
        ListLiteral,
        LocalInitializer,
        Location,
        MapEntry,
        MapLiteral,
        Member,
        MethodInvocation,
        Name,
        NamedExpression,
        NamedType,
        Node,
        Procedure,
        ProcedureKind,
        PropertyGet,
        PropertySet,
        Rethrow,
        ReturnStatement,
        Statement,
        StaticGet,
        StaticInvocation,
        StaticSet,
        StringConcatenation,
        SuperInitializer,
        SuperMethodInvocation,
        SuperPropertySet,
        SwitchCase,
        ThisExpression,
        TreeNode,
        TypeParameter,
        TypeParameterType,
        Typedef,
        TypedefType,
        VariableDeclaration,
        VariableGet,
        VariableSet,
        VoidType,
        setParents;

export 'kernel_shadow_ast.dart'
    show
        ArgumentsJudgment,
        AssertInitializerJudgment,
        AssertStatementJudgment,
        BreakJudgment,
        CascadeJudgment,
        ComplexAssignmentJudgment,
        ContinueSwitchJudgment,
        DeferredCheckJudgment,
        ExpressionStatementJudgment,
        FactoryConstructorInvocationJudgment,
        ShadowFieldInitializer,
        ForInJudgment,
        FunctionDeclarationJudgment,
        FunctionNodeJudgment,
        IfNullJudgment,
        IfJudgment,
        IllegalAssignmentJudgment,
        IndexAssignmentJudgment,
        InvalidConstructorInvocationJudgment,
        InvalidSuperInitializerJudgment,
        InvalidWriteJudgment,
        ShadowInvalidFieldInitializer,
        ShadowInvalidInitializer,
        LabeledStatementJudgment,
        LoadLibraryTearOffJudgment,
        MethodInvocationJudgment,
        NamedFunctionExpressionJudgment,
        NullAwareMethodInvocationJudgment,
        NullAwarePropertyGetJudgment,
        PropertyAssignmentJudgment,
        RedirectingInitializerJudgment,
        ReturnJudgment,
        ShadowLargeIntLiteral,
        StaticAssignmentJudgment,
        SuperInitializerJudgment,
        SuperMethodInvocationJudgment,
        SuperPropertyGetJudgment,
        SwitchCaseJudgment,
        SwitchStatementJudgment,
        SyntheticExpressionJudgment,
        UnresolvedTargetInvocationJudgment,
        UnresolvedVariableAssignmentJudgment,
        VariableAssignmentJudgment,
        VariableDeclarationJudgment,
        VariableGetJudgment,
        YieldJudgment;