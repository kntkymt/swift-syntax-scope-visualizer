import SwiftSyntax
@_spi(Experimental) import SwiftLexicalLookup

internal extension Range<AbsolutePosition> {
    var displayedUpperBound: AbsolutePosition {
        guard lowerBound != upperBound else {
            return upperBound
        }

        return AbsolutePosition(utf8Offset: upperBound.utf8Offset - 1)
    }
}

internal extension LookupName {
    // Flatten `equivalentNames` so each entry maps 1:1 to a displayable name.
    var flattened: [LookupName] {
        switch self {
        case .equivalentNames(let names):
            return names.flatMap(\.flattened)
        default:
            return [self]
        }
    }

    var kindLabel: String {
        switch self {
        case .identifier: return "identifier"
        case .declaration: return "declaration"
        case .implicit: return "implicit"
        case .equivalentNames: return "equivalent"
        }
    }

    var displayDescription: String {
        "\(kindLabel):\(identifier.name)"
    }
}

internal extension ScopeSyntax {
    // Run lookup at the scope's end with `finishInSequentialScope: true` so a
    // SequentialScopeSyntax (CodeBlock / SourceFile / ...) folds in names from
    // `IntroducingToSequentialParentScopeSyntax` children (e.g. `guard let`).
    // `LookupConfig` has no way to suppress parent-scope walking, so scopes that
    // delegate via `lookupInParent` (VariableDeclScope, MacroDeclScope, ...) leak
    // ancestor names. Drop results whose scope isn't this scope or its descendant.
    func lookupAtScopeEnd() -> [LookupName] {
        // IfExprSyntax.lookup short-circuits to the parent scope when the lookup
        // position falls inside its `elseBody`, so querying at the if's trimmed
        // upperBound (past the `else`) drops names bound by the if's
        // optional-binding conditions. Query inside the then-body (just before
        // the `else`) so `if let x = ...` style names are visible.
        let position: AbsolutePosition
        if let ifExpr = self.as(IfExprSyntax.self), ifExpr.elseKeyword != nil {
            position = ifExpr.body.trimmedRange.displayedUpperBound
        } else {
            position = trimmedRange.displayedUpperBound
        }

        let config = LookupConfig(finishInSequentialScope: true)
        let ownId = Syntax(self).id

        return lookup(nil, at: position, with: config)
            .filter { Syntax($0.scope).isSelfOrDescendant(of: ownId) }
            .flatMap(\.names)
            .sorted { $0.position < $1.position }
    }
}

private extension Syntax {
    func isSelfOrDescendant(of ancestorID: SyntaxIdentifier) -> Bool {
        var current: Syntax? = self
        while let node = current {
            if node.id == ancestorID { return true }
            current = node.parent
        }
        return false
    }
}

// `IntroducingToSequentialParentScopeSyntax` and its `namesIntroducedToSequentialParent`
// are SwiftLexicalLookup-internal, so we replicate the logic here for the only two
// conforming types: `GuardStmtSyntax` and `IfConfigDeclSyntax`.
internal extension Syntax {
    var introducedNameTextsToParent: [String] {
        if let guardStmt = self.as(GuardStmtSyntax.self) {
            return guardStmt.conditions.flatMap { (element) in
                Syntax(element.condition).introducedNameTexts
            }
        }

        if let ifConfigDecl = self.as(IfConfigDeclSyntax.self) {
            return ifConfigDecl.clauses.flatMap { (clause) in
                clause.elementSyntaxes.flatMap(\.introducedNameTexts)
            }
        }

        return []
    }

    var introducedNameTexts: [String] {
        switch self.as(SyntaxEnum.self) {
        case .identifierPattern(let pattern):
            guard pattern.identifier.tokenKind != .wildcard else { return [] }
            return [pattern.identifier.text]
        case .variableDecl(let decl):
            return decl.bindings.flatMap { Syntax($0.pattern).introducedNameTexts }
        case .tuplePattern(let pattern):
            return pattern.elements.flatMap { Syntax($0.pattern).introducedNameTexts }
        case .tupleExpr(let expr):
            return expr.elements.flatMap { Syntax($0).introducedNameTexts }
        case .labeledExpr(let expr):
            return Syntax(expr.expression).introducedNameTexts
        case .valueBindingPattern(let pattern):
            return Syntax(pattern.pattern).introducedNameTexts
        case .expressionPattern(let pattern):
            return Syntax(pattern.expression).introducedNameTexts
        case .sequenceExpr(let expr):
            return expr.elements.flatMap { Syntax($0).introducedNameTexts }
        case .patternExpr(let expr):
            return Syntax(expr.pattern).introducedNameTexts
        case .optionalBindingCondition(let condition):
            return Syntax(condition.pattern).introducedNameTexts
        case .matchingPatternCondition(let condition):
            return Syntax(condition.pattern).introducedNameTexts
        case .functionCallExpr(let expr):
            return expr.arguments.flatMap { Syntax($0.expression).introducedNameTexts }
        case .optionalChainingExpr(let expr):
            return Syntax(expr.expression).introducedNameTexts
        default:
            if let named = self.asProtocol(SyntaxProtocol.self) as? NamedDeclSyntax {
                return [named.name.text]
            }
            return []
        }
    }
}

private extension IfConfigClauseSyntax {
    var elementSyntaxes: [Syntax] {
        switch elements {
        case .statements(let list):
            return list.map { Syntax($0.item) }
        case .switchCases(let list):
            return list.map { Syntax($0) }
        case .decls(let list):
            return list.map { Syntax($0.decl) }
        case .postfixExpression(let expr):
            return [Syntax(expr)]
        case .attributes(let list):
            return list.map { Syntax($0) }
        case .none:
            return []
        }
    }
}
