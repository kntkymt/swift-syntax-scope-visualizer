import Testing
import SwiftParser
import SwiftSyntax
@testable import Pages

@Suite struct SyntaxTreeBuilderTests {
    @Test func buildsRootForSimpleStruct() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let root = buildSyntaxTree(from: syntax)
        #expect(root != nil)
        #expect(root?.typeName == "SourceFile")
    }

    @Test func skipsEmptyCollections() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let root = buildSyntaxTree(from: syntax)!

        #expect(!containsEmptyCollection(in: root))
        #expect(!contains(in: root, typeName: "AttributeList"))
        #expect(!contains(in: root, typeName: "DeclModifierList"))
    }

    @Test func keepsNonEmptyCollections() {
        let syntax = Parser.parse(source: "struct Foo {}; struct Bar {}")
        let root = buildSyntaxTree(from: syntax)!

        #expect(contains(in: root, typeName: "CodeBlockItemList"))
    }

    @Test func collectionElementsHaveNoLabel() {
        let syntax = Parser.parse(source: "struct Foo {}; struct Bar {}")
        let root = buildSyntaxTree(from: syntax)!
        let list = find(in: root, typeName: "CodeBlockItemList")!

        #expect(!list.children.isEmpty)
        for child in list.children {
            #expect(child.label == nil)
        }
    }

    @Test func layoutChildrenHaveLabels() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let root = buildSyntaxTree(from: syntax)!
        let structDecl = find(in: root, typeName: "StructDecl")!

        let labels = structDecl.children.compactMap { $0.label }
        #expect(labels.contains("name"))
        #expect(labels.contains("memberBlock"))
    }

    @Test func keywordTokensAreHidden() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let root = buildSyntaxTree(from: syntax)!
        let structDecl = find(in: root, typeName: "StructDecl")!

        let labels = structDecl.children.compactMap { $0.label }
        #expect(!labels.contains("structKeyword"))
    }

    @Test func punctuationTokensAreHidden() {
        let syntax = Parser.parse(source: "func f(a: Int) {}")
        let root = buildSyntaxTree(from: syntax)!

        let labels = collectLabels(in: root)
        #expect(!labels.contains("leftParen"))
        #expect(!labels.contains("rightParen"))
        #expect(!labels.contains("leftBrace"))
        #expect(!labels.contains("rightBrace"))
        #expect(!labels.contains("colon"))
    }

    @Test func onlyIdentifierTokensAreKept() {
        let syntax = Parser.parse(source: "let value = 42")
        let root = buildSyntaxTree(from: syntax)!

        let nameToken = find(in: root, typeName: "Token", whereLabel: "identifier")
        #expect(nameToken?.tokenText == "value")

        // The `42` integer-literal token is hidden along with the rest of the non-identifier
        // tokens.
        let literalToken = find(in: root, typeName: "Token", whereLabel: "literal")
        #expect(literalToken == nil)
    }

    @Test func tokenNodesCarryText() {
        let syntax = Parser.parse(source: "struct Foo {}")
        let root = buildSyntaxTree(from: syntax)!
        let structDecl = find(in: root, typeName: "StructDecl")!

        let nameToken = structDecl.children.first { $0.label == "name" }!
        #expect(nameToken.kind == .token)
        #expect(nameToken.tokenText == "Foo")
    }

    @Test func sourceFileIsScopeWithNoIntroducedNames() {
        let syntax = Parser.parse(source: "let x = 1")
        let root = buildSyntaxTree(from: syntax)!

        #expect(root.typeName == "SourceFile")
        #expect(root.isScope)
        #expect(root.introducedNames.isEmpty)
    }

    @Test func functionDeclIntroducesParameters() {
        let syntax = Parser.parse(source: "func f(a: Int, b: String) {}")
        let root = buildSyntaxTree(from: syntax)!
        let funcDecl = find(in: root, typeName: "FunctionDecl")!

        #expect(funcDecl.isScope)
        #expect(funcDecl.introducedNames == ["a", "b"])
    }

    @Test func codeBlockIntroducesLocalBindings() {
        let syntax = Parser.parse(source: "func f() { let x = 1; let y = 2 }")
        let root = buildSyntaxTree(from: syntax)!
        let codeBlock = find(in: root, typeName: "CodeBlock")!

        #expect(codeBlock.isScope)
        #expect(codeBlock.introducedNames == ["x", "y"])
    }

    @Test func nonScopeNodeHasEmptyIntroducedNames() {
        let syntax = Parser.parse(source: "let x = 1")
        let root = buildSyntaxTree(from: syntax)!
        let identifierToken = find(in: root, typeName: "Token", whereLabel: "identifier")!

        #expect(!identifierToken.isScope)
        #expect(identifierToken.introducedNames.isEmpty)
    }

    @Test func variableDeclScopeDoesNotLeakAncestorNames() {
        let syntax = Parser.parse(source: """
            class C {
                let outer = 1
                var x: Int { 0 }
            }
            """)
        let root = buildSyntaxTree(from: syntax)!
        let varDecl = find(in: root, typeName: "VariableDecl")!

        #expect(varDecl.isScope)
        #expect(varDecl.introducedNames.isEmpty)
    }

    @Test func codeBlockFoldsGuardLetIntoIntroducedNames() {
        let syntax = Parser.parse(source: """
            func f() {
                let a = 1
                guard let b = 10 else { return }
                let c = 1
            }
            """)
        let root = buildSyntaxTree(from: syntax)!
        let codeBlock = find(in: root, typeName: "CodeBlock")!

        #expect(codeBlock.introducedNames == ["a", "b", "c"])
    }

    @Test func guardStmtIntroducesBindingsToParent() {
        let syntax = Parser.parse(source: """
            func f(opt: Int?) {
                guard let x = opt, let y = opt else { return }
                _ = x + y
            }
            """)
        let root = buildSyntaxTree(from: syntax)!
        let guardStmt = find(in: root, typeName: "GuardStmt")!

        #expect(guardStmt.isScope)
        #expect(guardStmt.introducedNames.isEmpty)
        #expect(guardStmt.introducedNamesToParent == ["x", "y"])
    }

    @Test func ifConfigDeclIntroducesDeclsToParent() {
        let syntax = Parser.parse(source: """
            #if DEBUG
            let x = 1
            let y = 2
            #endif
            """)
        let root = buildSyntaxTree(from: syntax)!
        let ifConfig = find(in: root, typeName: "IfConfigDecl")!

        #expect(ifConfig.isScope)
        #expect(ifConfig.introducedNamesToParent == ["x", "y"])
    }

    @Test func nonIntroducingNodeHasEmptyIntroducedNamesToParent() {
        let syntax = Parser.parse(source: "func f(a: Int) { let x = 1 }")
        let root = buildSyntaxTree(from: syntax)!
        let funcDecl = find(in: root, typeName: "FunctionDecl")!

        #expect(funcDecl.introducedNamesToParent.isEmpty)
    }

    @Test func ifExprWithoutElseIntroducesOptionalBinding() {
        let syntax = Parser.parse(source: """
            func f() {
                if let a = 1 {
                    let a1 = 2
                }
            }
            """)
        let root = buildSyntaxTree(from: syntax)!
        let ifExpr = find(in: root, typeName: "IfExpr")!

        #expect(ifExpr.introducedNames.contains("a"))
    }

    @Test func ifExprWithElseIfIntroducesOuterOptionalBinding() {
        let syntax = Parser.parse(source: """
            func f() {
                if let a = 1 {
                    let a1 = 2
                } else if let b = 2 {
                    let b1 = 2
                }
            }
            """)
        let root = buildSyntaxTree(from: syntax)!
        let outerIf = find(in: root, typeName: "IfExpr")!

        #expect(outerIf.introducedNames.contains("a"))
    }

    @Test func ifExprWithPlainElseIntroducesOptionalBinding() {
        let syntax = Parser.parse(source: """
            func f() {
                if let a = 1 {
                    let a1 = 2
                } else {
                    let z = 0
                }
            }
            """)
        let root = buildSyntaxTree(from: syntax)!
        let ifExpr = find(in: root, typeName: "IfExpr")!

        #expect(ifExpr.introducedNames.contains("a"))
    }

    @Test func ifExprWithElseIntroducesMultipleOptionalBindings() {
        let syntax = Parser.parse(source: """
            func f(opt: Int?) {
                if let a = opt, let b = opt {
                    _ = a + b
                } else {
                    return
                }
            }
            """)
        let root = buildSyntaxTree(from: syntax)!
        let ifExpr = find(in: root, typeName: "IfExpr")!

        #expect(ifExpr.introducedNames.contains("a"))
        #expect(ifExpr.introducedNames.contains("b"))
    }

    @Test func sourceRangeUsesLineColumnFormat() {
        let syntax = Parser.parse(source: "let x = 1")
        let root = buildSyntaxTree(from: syntax)!

        #expect(root.sourceRange == "[1:1 - 1:10]")
    }

    @Test func nodeIdsAreUnique() {
        let syntax = Parser.parse(source: """
            struct Foo {
                let x: Int = 1
                func bar() {}
            }
            """)
        let root = buildSyntaxTree(from: syntax)!

        var seen: Set<Int> = []
        collectIds(in: root, into: &seen)
        let total = countNodes(in: root)
        #expect(seen.count == total)
    }
}

private func contains(in node: SyntaxTreeNode, typeName: String) -> Bool {
    if node.typeName == typeName { return true }
    return node.children.contains { contains(in: $0, typeName: typeName) }
}

private func find(in node: SyntaxTreeNode, typeName: String) -> SyntaxTreeNode? {
    if node.typeName == typeName { return node }
    for child in node.children {
        if let found = find(in: child, typeName: typeName) {
            return found
        }
    }
    return nil
}

private func find(in node: SyntaxTreeNode, typeName: String, whereLabel label: String) -> SyntaxTreeNode? {
    if node.typeName == typeName && node.label == label { return node }
    for child in node.children {
        if let found = find(in: child, typeName: typeName, whereLabel: label) {
            return found
        }
    }
    return nil
}

private func collectLabels(in node: SyntaxTreeNode) -> Set<String> {
    var labels: Set<String> = []
    if let label = node.label { labels.insert(label) }
    for child in node.children {
        labels.formUnion(collectLabels(in: child))
    }
    return labels
}

private func containsEmptyCollection(in node: SyntaxTreeNode) -> Bool {
    if node.kind == .collection && node.children.isEmpty {
        return true
    }
    return node.children.contains { containsEmptyCollection(in: $0) }
}

private func collectIds(in node: SyntaxTreeNode, into set: inout Set<Int>) {
    set.insert(node.id)
    for child in node.children {
        collectIds(in: child, into: &set)
    }
}

private func countNodes(in node: SyntaxTreeNode) -> Int {
    1 + node.children.reduce(0) { $0 + countNodes(in: $1) }
}
