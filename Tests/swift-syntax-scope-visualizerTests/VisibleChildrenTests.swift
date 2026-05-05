import Testing
import SwiftParser
import SwiftSyntax
@testable import Pages

@Suite struct VisibleChildrenTests {
    @Test func hidesEmptyCollections() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let structDecl = find(in: Syntax(syntax), typeName: "StructDeclSyntax")!

        let visible = structDecl.visibleChildren(
            config: SwiftLexicalLookupPane.VisibleNodeConfig(
                hideEmptyCollections: true,
                hideTokens: false,
                hideNonScope: false
            )
        )

        #expect(!visible.contains { $0.is(AttributeListSyntax.self) })
        #expect(!visible.contains { $0.is(DeclModifierListSyntax.self) })
    }

    @Test func keepsEmptyCollectionsWhenFlagIsOff() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let structDecl = find(in: Syntax(syntax), typeName: "StructDeclSyntax")!

        let visible = structDecl.visibleChildren(
            config: SwiftLexicalLookupPane.VisibleNodeConfig(
                hideEmptyCollections: false,
                hideTokens: false,
                hideNonScope: false
            )
        )

        #expect(visible.contains { $0.is(AttributeListSyntax.self) })
        #expect(visible.contains { $0.is(DeclModifierListSyntax.self) })
    }

    @Test func hidesTokens() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let structDecl = find(in: Syntax(syntax), typeName: "StructDeclSyntax")!

        let visible = structDecl.visibleChildren(
            config: SwiftLexicalLookupPane.VisibleNodeConfig(
                hideEmptyCollections: false,
                hideTokens: true,
                hideNonScope: false
            )
        )

        #expect(!visible.contains { $0.is(TokenSyntax.self) })
    }

    @Test func keepsTokensWhenFlagIsOff() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let structDecl = find(in: Syntax(syntax), typeName: "StructDeclSyntax")!

        let visible = structDecl.visibleChildren(
            config: SwiftLexicalLookupPane.VisibleNodeConfig(
                hideEmptyCollections: false,
                hideTokens: false,
                hideNonScope: false
            )
        )

        #expect(visible.contains { $0.is(TokenSyntax.self) })
    }

    @Test func liftsScopeDescendantsThroughNonScopeChildren() {
        let syntax = Parser.parse(source: "struct Foo {}")

        // SourceFile (Scope) の直接の子は CodeBlockItemList (Non-Scope) と eofToken。
        // hideNonScope を立てると CodeBlockItemList は子の StructDecl (Scope) に置き換わる。
        let visible = Syntax(syntax).visibleChildren(
            config: SwiftLexicalLookupPane.VisibleNodeConfig(
                hideEmptyCollections: false,
                hideTokens: true,
                hideNonScope: true
            )
        )

        #expect(!visible.contains { $0.is(CodeBlockItemListSyntax.self) })
        #expect(visible.contains { $0.is(StructDeclSyntax.self) })
    }

    @Test func keepsNonScopeChildrenWhenFlagIsOff() {
        let syntax = Parser.parse(source: "struct Foo {}")

        let visible = Syntax(syntax).visibleChildren(
            config: SwiftLexicalLookupPane.VisibleNodeConfig(
                hideEmptyCollections: false,
                hideTokens: true,
                hideNonScope: false
            )
        )

        #expect(visible.contains { $0.is(CodeBlockItemListSyntax.self) })
    }

    @Test func hidingAllFlagsReturnsScopeOnlyVisibleTree() {
        let syntax = Parser.parse(
            source: """
                func f() {
                    let x = 1
                }
                """
        )

        // SourceFile から見て CodeBlockItemList(Non-Scope) -> CodeBlockItem(Non-Scope)
        // -> FunctionDecl(Scope) と辿る。3フラグ全有効で FunctionDecl が直下に持ち上がる。
        let visible = Syntax(syntax).visibleChildren(
            config: SwiftLexicalLookupPane.VisibleNodeConfig(
                hideEmptyCollections: true,
                hideTokens: true,
                hideNonScope: true
            )
        )

        #expect(visible.count == 1)
        #expect(visible.first?.is(FunctionDeclSyntax.self) == true)
    }
}

private func find(in syntax: Syntax, typeName: String) -> Syntax? {
    if "\(syntax.syntaxNodeType)" == typeName { return syntax }
    for child in syntax.children(viewMode: .sourceAccurate) {
        if let found = find(in: child, typeName: typeName) {
            return found
        }
    }
    return nil
}
