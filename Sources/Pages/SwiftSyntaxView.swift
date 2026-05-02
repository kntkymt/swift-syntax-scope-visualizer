@_spi(RawSyntax) import SwiftSyntax
@_spi(Experimental) import SwiftLexicalLookup
import React

internal struct SwiftSyntaxView: Component {
    let syntax: any SyntaxProtocol

    @State var hideNonScope: Bool = false

    func render() -> Node {
        let root = buildSyntaxTree(from: syntax)

        let onToggle = EventListener { _ in
            hideNonScope.toggle()
        }

        return Pane(
            header: {
                h4(style: .init().margin("0")) { "Swift Lexical Lookup" }

                button(
                    style: .init()
                        .padding("4px 10px")
                        .border("1px solid #ccc")
                        .borderRadius("4px")
                        .backgroundColor(hideNonScope ? "#495057" : "#fff")
                        .color(hideNonScope ? "#fff" : "#000")
                        .cursor("pointer")
                        .font("inherit"),
                    listeners: .init().click(onToggle)
                ) {
                    "Hide non-Scope Syntax"
                }
            }
        ) {
            if let root {
                SyntaxTreeNodeView(node: root, hideNonScope: hideNonScope)
            }
        }
    }
}

internal struct SyntaxTreeNodeView: Component {
    var key: AnyHashable? { node.id }

    let node: SyntaxTreeNode
    let hideNonScope: Bool

    func render() -> Node {
        let typeColor = node.isScope ? "#c92a2a" : "#0a66c2"

        return HoverHighlight {
            Accordion {
                span(style: .init().color(typeColor)) {
                    if let scopeDebugName = node.scopeDebugName {
                        "\(node.typeName): \(scopeDebugName)"
                    } else {
                        node.typeName
                    }
                }

                if let token = node.tokenText {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color("#666")
                    ) {
                        "\"\(token)\""
                    }
                }

                span(
                    style: .init()
                        .marginLeft("8px")
                        .color("#666")
                ) {
                    node.sourceRange
                }

                if !node.introducedNames.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color("#666")
                    ) {
                        "introduces=[\(node.introducedNames.joined(separator: ", "))]"
                    }
                }

                if !node.introducedNamesToParent.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color("#666")
                    ) {
                        "introducesToParent=[\(node.introducedNamesToParent.joined(separator: ", "))]"
                    }
                }
            } body: {
                node.visibleChildren(hideNonScope: hideNonScope).map { (child) in
                    SyntaxTreeNodeView(node: child, hideNonScope: hideNonScope)
                }
            }
        }
    }
}

internal enum SyntaxTreeNodeKind {
    case layout
    case collection
    case token
}

internal struct SyntaxTreeNode {
    let id: Int
    let label: String?
    let typeName: String
    let kind: SyntaxTreeNodeKind
    let tokenText: String?
    let sourceRange: String
    let isScope: Bool
    let scopeDebugName: String?
    let introducedNames: [String]
    let introducedNamesToParent: [String]
    let children: [SyntaxTreeNode]
}

internal extension SyntaxTreeNode {
    // Lift scope descendants of hidden non-scope children up to this level so the
    // visible tree only contains scope nodes while preserving ancestor order.
    func visibleChildren(hideNonScope: Bool) -> [SyntaxTreeNode] {
        guard hideNonScope else { return children }

        return children.flatMap { (child) -> [SyntaxTreeNode] in
            if child.isScope {
                return [child]
            } else {
                return child.visibleChildren(hideNonScope: hideNonScope)
            }
        }
    }
}

internal func buildSyntaxTree(from syntax: any SyntaxProtocol) -> SyntaxTreeNode? {
    var nextId = 0
    let converter = SourceLocationConverter(fileName: "", tree: syntax.root)

    func build(_ syntax: Syntax, label: String?) -> SyntaxTreeNode? {
        let isCollection: Bool
        switch syntax.syntaxNodeType.structure {
        case .collection: isCollection = true
        default: isCollection = false
        }

        let childList = syntax.children(viewMode: .sourceAccurate)

        // Hide empty collections (e.g. an empty `attributes`, `modifiers` list).
        if isCollection && childList.isEmpty {
            return nil
        }

        let id = nextId
        nextId += 1

        let kind: SyntaxTreeNodeKind
        let tokenText: String?
        if let token = syntax.as(TokenSyntax.self) {
            // Only show identifier tokens. Everything else (keywords, punctuation, literals,
            // operators, quotes, EOF, …) is either fully determined by the surrounding syntax
            // node or visible verbatim in the source pane.
            guard case .identifier = token.tokenKind else {
                return nil
            }
            kind = .token
            tokenText = token.text
        } else if isCollection {
            kind = .collection
            tokenText = nil
        } else {
            kind = .layout
            tokenText = nil
        }

        let rawTypeName = "\(syntax.syntaxNodeType)"
        let typeName = rawTypeName.hasSuffix("Syntax")
            ? String(rawTypeName.dropLast("Syntax".count))
            : rawTypeName

        let scope = syntax.asProtocol(SyntaxProtocol.self) as? ScopeSyntax
        let introducedNames = scope?.lookupAtScopeEnd.map(\.displayText) ?? []
        let introducedNamesToParent = syntax.introducedNameTextsToParent

        let children: [SyntaxTreeNode] = childList.compactMap { (child) in
            let childLabel = child.keyPathInParent.flatMap { childName($0) }
            return build(child, label: childLabel)
        }

        return SyntaxTreeNode(
            id: id,
            label: label,
            typeName: typeName,
            kind: kind,
            tokenText: tokenText,
            sourceRange: syntax.sourceRangeDescription(converter: converter),
            isScope: scope != nil,
            scopeDebugName: scope?.scopeDebugName,
            introducedNames: introducedNames,
            introducedNamesToParent: introducedNamesToParent,
            children: children
        )
    }

    return build(Syntax(syntax), label: nil)
}

private extension SyntaxProtocol {
    func sourceRangeDescription(converter: SourceLocationConverter) -> String {
        let range = sourceRange(converter: converter)
        return "[\(range.start.line):\(range.start.column) - \(range.end.line):\(range.end.column)]"
    }
}

private extension Range<AbsolutePosition> {
    var displayedUpperBound: AbsolutePosition {
        guard lowerBound != upperBound else {
            return upperBound
        }

        return AbsolutePosition(utf8Offset: upperBound.utf8Offset - 1)
    }
}

private extension LookupName {
    var displayText: String {
        switch self {
        case .equivalentNames(let names):
            return names.map(\.displayText).joined(separator: "/")
        default:
            return identifier.name
        }
    }
}

private extension ScopeSyntax {
    // Run lookup at the scope's end with `finishInSequentialScope: true` so a
    // SequentialScopeSyntax (CodeBlock / SourceFile / ...) folds in names from
    // `IntroducingToSequentialParentScopeSyntax` children (e.g. `guard let`).
    // `LookupConfig` has no way to suppress parent-scope walking, so scopes that
    // delegate via `lookupInParent` (VariableDeclScope, MacroDeclScope, ...) leak
    // ancestor names. Drop results whose scope isn't this scope or its descendant.
    var lookupAtScopeEnd: [LookupName] {
        let position = trimmedRange.displayedUpperBound
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
private extension Syntax {
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
