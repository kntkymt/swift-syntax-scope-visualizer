@_spi(RawSyntax) import SwiftSyntax
@_spi(Experimental) import SwiftLexicalLookup
import React

internal struct SwiftLexicalLookupPane: Component {
    let syntax: any SyntaxProtocol

    @State var hideNonScope: Bool = false

    var deps: Deps? {
        [syntax.id]
    }

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
            div(style: .init().whiteSpace("nowrap")) {
                if let root {
                    SyntaxTreeNodeView(node: root, hideNonScope: hideNonScope)
                }
            }
        }
    }
}

private struct SyntaxTreeNodeView: Component {
    var key: AnyHashable? { node.id }

    var deps: Deps? {
        [node, hideNonScope]
    }

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

                if !node.declNames.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color("#666")
                    ) {
                        node.declNames.lazy.map { "\"\($0)\"" }.joined(separator: ", ")
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

internal struct SyntaxTreeNode: Hashable {
    let id: SyntaxIdentifier
    let typeName: String
    let tokenText: String?
    let sourceRange: String
    let isScope: Bool
    let scopeDebugName: String?
    let introducedNames: [String]
    let introducedNamesToParent: [String]
    let declNames: [String]
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
    let converter = SourceLocationConverter(fileName: "", tree: syntax.root)

    func build(_ syntax: Syntax) -> SyntaxTreeNode? {
        let childList = syntax.children(viewMode: .sourceAccurate)

        // Hide empty collections (e.g. an empty `attributes`, `modifiers` list).
        if syntax.syntaxNodeType.structure.isCollection && childList.isEmpty {
            return nil
        }

        let tokenText: String?
        if let token = syntax.as(TokenSyntax.self) {
            // Only show identifier tokens. Everything else (keywords, punctuation, literals,
            // operators, quotes, EOF, …) is either fully determined by the surrounding syntax
            // node or visible verbatim in the source pane.
            guard case .identifier = token.tokenKind else {
                return nil
            }
            tokenText = token.text
        } else {
            tokenText = nil
        }

        let rawTypeName = "\(syntax.syntaxNodeType)"
        let typeName =
            rawTypeName.hasSuffix("Syntax")
            ? String(rawTypeName.dropLast("Syntax".count))
            : rawTypeName

        let scope = syntax.asProtocol(SyntaxProtocol.self) as? ScopeSyntax
        let introducedNames = scope?.lookupAtScopeEnd().map(\.identifier.name) ?? []
        let introducedNamesToParent = syntax.introducedNameTextsToParent

        let children: [SyntaxTreeNode] = childList.compactMap { (child) in
            return build(child)
        }

        return SyntaxTreeNode(
            id: syntax.id,
            typeName: typeName,
            tokenText: tokenText,
            sourceRange: syntax.range.description(converter: converter),
            isScope: scope != nil,
            scopeDebugName: scope?.scopeDebugName,
            introducedNames: introducedNames,
            introducedNamesToParent: introducedNamesToParent,
            declNames: syntax.declNames,
            children: children
        )
    }

    return build(Syntax(syntax))
}
