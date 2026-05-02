@_spi(RawSyntax) import SwiftSyntax
import React

internal struct SwiftSyntaxView: Component {
    let syntax: any SyntaxProtocol

    func render() -> Node {
        let root = buildSyntaxTree(from: syntax)

        return div(
            style: .init()
                .flex("1 1 0")
                .minWidth("0")
                .height("100%")
                .overflow("auto")
                .padding("8px")
                .borderRight("1px solid #ddd")
                .boxSizing("border-box")
                .fontFamily("ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace")
        ) {
            if let root {
                SyntaxTreeNodeView(node: root)
            }
        }
    }
}

internal struct SyntaxTreeNodeView: Component {
    var key: AnyHashable? { node.id }

    let node: SyntaxTreeNode

    @State var isExpanded: Bool = true
    @State var isHovered: Bool = false

    func render() -> Node {
        let hasChildren = !node.children.isEmpty

        let onToggle = EventListener { (_) in
            self.isExpanded.toggle()
        }

        // Highlight only the deepest hovered node and its descendants by stopping the mouse event
        // from bubbling. The descendants inherit the background through normal DOM stacking,
        // while ancestors receive a `mouseout` and clear their highlight as the cursor enters
        // a child.
        let onMouseOver = EventListener { (event) in
            _ = event.jsValue.stopPropagation()
            self.isHovered = true
        }
        let onMouseOut = EventListener { (event) in
            _ = event.jsValue.stopPropagation()
            self.isHovered = false
        }

        let typeColor: String
        switch node.kind {
        case .layout: typeColor = "#0a66c2"
        case .collection: typeColor = "#a4508b"
        case .token: typeColor = "#1f7a3f"
        }

        return div(
            style: .init()
                .backgroundColor(isHovered ? "rgba(100, 149, 237, 0.25)" : "transparent"),
            listeners: .init()
                .mouseover(onMouseOver)
                .mouseout(onMouseOut)
        ) {
            div(
                style: .init()
                    .display("flex")
                    .flexDirection("row")
                    .alignItems("baseline")
                    .cursor(hasChildren ? "pointer" : "default")
                    .userSelect("none"),
                listeners: .init().click(onToggle)
            ) {
                span(
                    style: .init()
                        .display("inline-block")
                        .width("12px")
                        .color("#888")
                ) {
                    hasChildren ? (isExpanded ? "▾" : "▸") : ""
                }

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
            }

            if hasChildren && isExpanded {
                div(
                    style: .init()
                        .paddingLeft("12px")
                        .marginLeft("4px")
                        .borderLeft("1px solid #eee")
                ) {
                    node.children.map { (child) in
                        SyntaxTreeNodeView(node: child)
                    }
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
