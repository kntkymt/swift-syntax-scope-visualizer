import SwiftSyntax
@_spi(Experimental) import SwiftLexicalLookup

internal extension Range<AbsolutePosition> {
    var lastContainedPosition: AbsolutePosition {
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

    func displayDescription(converter: SourceLocationConverter) -> String {
        if case .identifier(_, let accessibleAfter) = self, let accessibleAfter {
            let location = converter.location(for: accessibleAfter)
            return "\(displayDescription) \(location.line):\(location.column)-"
        }

        return displayDescription
    }

    // Avoids `LookupName.identifier`'s `Identifier(_:)!` force-unwrap so e.g.
    // operator decls (whose `name` token is not an identifier token) don't crash.
    var nameText: String? {
        switch self {
        case .identifier(let syntax, _):
            return syntax.as(IdentifierPatternSyntax.self)?.identifier.text
        case .declaration(let syntax):
            return (syntax.asProtocol(SyntaxProtocol.self) as? NamedDeclSyntax)?.name.text
        case .implicit, .equivalentNames:
            return nil
        }
    }
}

internal extension SyntaxProtocol {
    var nearestEnclosingScope: ScopeSyntax? {
        var current: Syntax? = Syntax(self)
        while let node = current {
            if let scope = node.asProtocol(SyntaxProtocol.self) as? ScopeSyntax {
                return scope
            }
            current = node.parent
        }
        return nil
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
            position = ifExpr.body.trimmedRange.lastContainedPosition
        } else {
            position = trimmedRange.lastContainedPosition
        }

        let config = SwiftLexicalLookup.LookupConfig(finishInSequentialScope: true)
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
    var introducedLookupNamesToParent: [LookupName] {
        if let guardStmt = self.as(GuardStmtSyntax.self) {
            return guardStmt.conditions.flatMap { (element) in
                Syntax(element.condition).introducedLookupNames(
                    accessibleAfter: element.endPosition
                )
            }
        }

        if let ifConfigDecl = self.as(IfConfigDeclSyntax.self) {
            return ifConfigDecl.clauses.flatMap { (clause) in
                clause.elementSyntaxes.flatMap { (element) in
                    element.introducedLookupNames(accessibleAfter: element.endPosition)
                }
            }
        }

        return []
    }

    func introducedLookupNames(accessibleAfter: AbsolutePosition? = nil) -> [LookupName] {
        switch self.as(SyntaxEnum.self) {
        case .identifierPattern(let pattern):
            guard pattern.identifier.tokenKind != .wildcard else { return [] }
            return [.identifier(Syntax(pattern), accessibleAfter: accessibleAfter)]
        case .variableDecl(let decl):
            return decl.bindings.flatMap { (binding) in
                Syntax(binding.pattern).introducedLookupNames(
                    accessibleAfter: accessibleAfter != nil
                        ? binding.endPositionBeforeTrailingTrivia : nil
                )
            }
        case .tuplePattern(let pattern):
            return pattern.elements.flatMap {
                Syntax($0.pattern).introducedLookupNames(accessibleAfter: accessibleAfter)
            }
        case .tupleExpr(let expr):
            return expr.elements.flatMap {
                Syntax($0).introducedLookupNames(accessibleAfter: accessibleAfter)
            }
        case .labeledExpr(let expr):
            return Syntax(expr.expression).introducedLookupNames(accessibleAfter: accessibleAfter)
        case .valueBindingPattern(let pattern):
            return Syntax(pattern.pattern).introducedLookupNames(accessibleAfter: accessibleAfter)
        case .expressionPattern(let pattern):
            return Syntax(pattern.expression).introducedLookupNames(
                accessibleAfter: accessibleAfter
            )
        case .sequenceExpr(let expr):
            return expr.elements.flatMap {
                Syntax($0).introducedLookupNames(accessibleAfter: accessibleAfter)
            }
        case .patternExpr(let expr):
            return Syntax(expr.pattern).introducedLookupNames(accessibleAfter: accessibleAfter)
        case .optionalBindingCondition(let condition):
            return Syntax(condition.pattern).introducedLookupNames(accessibleAfter: accessibleAfter)
        case .matchingPatternCondition(let condition):
            return Syntax(condition.pattern).introducedLookupNames(accessibleAfter: accessibleAfter)
        case .functionCallExpr(let expr):
            return expr.arguments.flatMap {
                Syntax($0.expression).introducedLookupNames(accessibleAfter: accessibleAfter)
            }
        case .optionalChainingExpr(let expr):
            return Syntax(expr.expression).introducedLookupNames(accessibleAfter: accessibleAfter)
        default:
            if let named = self.asProtocol(SyntaxProtocol.self) as? NamedDeclSyntax {
                return [.declaration(Syntax(named))]
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
