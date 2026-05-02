@_spi(RawSyntax) import SwiftSyntax
import React

internal struct SwiftSyntaxView: Component {
    let syntax: any SyntaxProtocol

    func render() -> Node {
        let root = buildSyntaxTree(from: syntax)

        return Pane {
            if let root {
                SyntaxTreeNodeView(node: root)
            }
        }
    }
}

internal struct SyntaxTreeNodeView: Component {
    var key: AnyHashable? { node.id }

    let node: SyntaxTreeNode

    func render() -> Node {
        let typeColor: String
        switch node.kind {
        case .layout: typeColor = "#0a66c2"
        case .collection: typeColor = "#a4508b"
        case .token: typeColor = "#1f7a3f"
        }

        return HoverHighlight {
            Accordion {
                if let label = node.label {
                    span(style: .init().color("#b1591a")) {
                        "\(label): "
                    }
                }

                span(style: .init().color(typeColor)) {
                    node.typeName
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
            } body: {
                node.children.map { (child) in
                    SyntaxTreeNodeView(node: child)
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
    let children: [SyntaxTreeNode]
}

internal func buildSyntaxTree(from syntax: any SyntaxProtocol) -> SyntaxTreeNode? {
    var nextId = 0

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
            children: children
        )
    }

    return build(Syntax(syntax), label: nil)
}
