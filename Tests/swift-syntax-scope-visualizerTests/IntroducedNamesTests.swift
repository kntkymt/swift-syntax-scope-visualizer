import Testing
import SwiftParser
import SwiftSyntax
@testable import Pages

@Suite struct IntroducedNamesTests {
    @Test func sourceFileIsScopeWithNoIntroducedNames() {
        let syntax = Parser.parse(source: "let x = 1")

        #expect(syntax.isScope)
        #expect(syntax.introducedNames.isEmpty)
    }

    @Test func functionDeclIntroducesParameters() {
        let syntax = Parser.parse(source: "func f(a: Int, b: String) {}")
        let funcDecl = find(in: Syntax(syntax), typeName: "FunctionDeclSyntax")!

        #expect(funcDecl.isScope)
        #expect(funcDecl.introducedNames == ["a", "b"])
    }

    @Test func codeBlockIntroducesLocalBindings() {
        let syntax = Parser.parse(source: "func f() { let x = 1; let y = 2 }")
        let codeBlock = find(in: Syntax(syntax), typeName: "CodeBlockSyntax")!

        #expect(codeBlock.isScope)
        #expect(codeBlock.introducedNames == ["x", "y"])
    }

    @Test func nonScopeNodeHasEmptyIntroducedNames() {
        let syntax = Parser.parse(source: "let x = 1")
        let pattern = find(in: Syntax(syntax), typeName: "IdentifierPatternSyntax")!

        #expect(!pattern.isScope)
        #expect(pattern.introducedNames.isEmpty)
    }

    @Test func variableDeclScopeDoesNotLeakAncestorNames() {
        let syntax = Parser.parse(
            source: """
                class C {
                    let outer = 1
                    var x: Int { 0 }
                }
                """
        )
        let varDecl = find(in: Syntax(syntax), typeName: "VariableDeclSyntax")!

        #expect(varDecl.isScope)
        #expect(varDecl.introducedNames.isEmpty)
    }

    @Test func codeBlockFoldsGuardLetIntoIntroducedNames() {
        let syntax = Parser.parse(
            source: """
                func f() {
                    let a = 1
                    guard let b = 10 else { return }
                    let c = 1
                }
                """
        )
        let codeBlock = find(in: Syntax(syntax), typeName: "CodeBlockSyntax")!

        #expect(codeBlock.introducedNames == ["a", "b", "c"])
    }

    @Test func guardStmtIntroducesBindingsToParent() {
        let syntax = Parser.parse(
            source: """
                func f(opt: Int?) {
                    guard let x = opt, let y = opt else { return }
                    _ = x + y
                }
                """
        )
        let guardStmt = find(in: Syntax(syntax), typeName: "GuardStmtSyntax")!

        #expect(guardStmt.isScope)
        #expect(guardStmt.introducedNames.isEmpty)
        #expect(guardStmt.introducedNamesToParent == ["x", "y"])
    }

    @Test func ifConfigDeclIntroducesDeclsToParent() {
        let syntax = Parser.parse(
            source: """
                #if DEBUG
                let x = 1
                let y = 2
                #endif
                """
        )
        let ifConfig = find(in: Syntax(syntax), typeName: "IfConfigDeclSyntax")!

        #expect(ifConfig.isScope)
        #expect(ifConfig.introducedNamesToParent == ["x", "y"])
    }

    @Test func nonIntroducingNodeHasEmptyIntroducedNamesToParent() {
        let syntax = Parser.parse(source: "func f(a: Int) { let x = 1 }")
        let funcDecl = find(in: Syntax(syntax), typeName: "FunctionDeclSyntax")!

        #expect(funcDecl.introducedNamesToParent.isEmpty)
    }

    @Test func ifExprWithoutElseIntroducesOptionalBinding() {
        let syntax = Parser.parse(
            source: """
                func f() {
                    if let a = 1 {
                        let a1 = 2
                    }
                }
                """
        )
        let ifExpr = find(in: Syntax(syntax), typeName: "IfExprSyntax")!

        #expect(ifExpr.introducedNames.contains("a"))
    }

    @Test func ifExprWithElseIfIntroducesOuterOptionalBinding() {
        let syntax = Parser.parse(
            source: """
                func f() {
                    if let a = 1 {
                        let a1 = 2
                    } else if let b = 2 {
                        let b1 = 2
                    }
                }
                """
        )
        let outerIf = find(in: Syntax(syntax), typeName: "IfExprSyntax")!

        #expect(outerIf.introducedNames.contains("a"))
    }

    @Test func ifExprWithPlainElseIntroducesOptionalBinding() {
        let syntax = Parser.parse(
            source: """
                func f() {
                    if let a = 1 {
                        let a1 = 2
                    } else {
                        let z = 0
                    }
                }
                """
        )
        let ifExpr = find(in: Syntax(syntax), typeName: "IfExprSyntax")!

        #expect(ifExpr.introducedNames.contains("a"))
    }

    @Test func ifExprWithElseIntroducesMultipleOptionalBindings() {
        let syntax = Parser.parse(
            source: """
                func f(opt: Int?) {
                    if let a = opt, let b = opt {
                        _ = a + b
                    } else {
                        return
                    }
                }
                """
        )
        let ifExpr = find(in: Syntax(syntax), typeName: "IfExprSyntax")!

        #expect(ifExpr.introducedNames.contains("a"))
        #expect(ifExpr.introducedNames.contains("b"))
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
