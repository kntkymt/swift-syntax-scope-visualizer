@_spi(RawSyntax) import SwiftSyntax
@_spi(Experimental) import SwiftLexicalLookup
import React

internal struct SwiftLexicalLookupPane: Component {
    let syntax: any SyntaxProtocol

    @State var hideEmptyCollections: Bool = true
    @State var hideTokens: Bool = true
    @State var hideNonScope: Bool = false
    @State var isPopoverOpen: Bool = false

    var deps: Deps? {
        [syntax.id]
    }

    func render() -> Node {
        let converter = SourceLocationConverter(fileName: "", tree: syntax.root)
        let isFiltered = hideEmptyCollections || hideTokens || hideNonScope

        let onTogglePopover = EventListener { _ in
            isPopoverOpen.toggle()
        }
        let onToggleEmptyCollections = EventListener { _ in
            hideEmptyCollections.toggle()
        }
        let onToggleTokens = EventListener { _ in
            hideTokens.toggle()
        }
        let onToggleNonScope = EventListener { _ in
            hideNonScope.toggle()
        }

        return Pane(
            header: {
                h4(style: .init().margin("0")) { "Swift Lexical Lookup" }

                div(style: .init().position("relative")) {
                    button(
                        style: .init()
                            .padding("4px 10px")
                            .border("1px solid #ccc")
                            .borderRadius("4px")
                            .backgroundColor(isFiltered ? "#495057" : "#fff")
                            .color(isFiltered ? "#fff" : "#000")
                            .cursor("pointer")
                            .font("inherit"),
                        listeners: .init().click(onTogglePopover)
                    ) {
                        "Visible Nodes"
                    }

                    if isPopoverOpen {
                        VisibilityPopover(
                            hideEmptyCollections: hideEmptyCollections,
                            hideTokens: hideTokens,
                            hideNonScope: hideNonScope,
                            onToggleEmptyCollections: onToggleEmptyCollections,
                            onToggleTokens: onToggleTokens,
                            onToggleNonScope: onToggleNonScope
                        )
                    }
                }
            }
        ) {
            div(style: .init().whiteSpace("nowrap")) {
                SyntaxTreeNodeView(
                    node: syntax,
                    converter: converter,
                    hideEmptyCollections: hideEmptyCollections,
                    hideTokens: hideTokens,
                    hideNonScope: hideNonScope
                )
            }
        }
    }
}

private struct SyntaxTreeNodeView: Component {
    var key: AnyHashable? { node.id }

    var deps: Deps? {
        [node.id, ObjectIdentifier(converter), hideEmptyCollections, hideTokens, hideNonScope]
    }

    let node: any SyntaxProtocol
    let converter: SourceLocationConverter
    let hideEmptyCollections: Bool
    let hideTokens: Bool
    let hideNonScope: Bool

    func render() -> Node {
        // Avoid declaring `scopeDebugName` on `SyntaxProtocol`: it shadows the
        // `ScopeSyntax` requirement of the same name and recurses infinitely.
        let scope = Syntax(node).asProtocol(SyntaxProtocol.self) as? ScopeSyntax
        let typeColor = node.isScope ? "#c92a2a" : "#0a66c2"
        let introducedNames = node.introducedNames
        let introducedNamesToParent = node.introducedNamesToParent
        let declNames = node.declNames

        return HoverHighlight {
            Accordion {
                span(style: .init().color(typeColor)) {
                    if let scopeDebugName = scope?.scopeDebugName {
                        "\(node.typeName): \(scopeDebugName)"
                    } else {
                        node.typeName
                    }
                }

                if let token = node.as(TokenSyntax.self) {
                    span(
                        style: .init()
                            .marginLeft("4px")
                            .color("#666")
                    ) {
                        token.tokenKind == .endOfFile ? ".eof" : "\"\(token.text)\""
                    }
                }

                if !declNames.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color("#666")
                    ) {
                        declNames.lazy.map { "\"\($0)\"" }.joined(separator: ", ")
                    }
                }

                span(
                    style: .init()
                        .marginLeft("8px")
                        .color("#666")
                ) {
                    node.range.description(converter: converter)
                }

                if !introducedNames.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color("#666")
                    ) {
                        "introduces=[\(introducedNames.joined(separator: ", "))]"
                    }
                }

                if !introducedNamesToParent.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color("#666")
                    ) {
                        "introducesToParent=[\(introducedNamesToParent.joined(separator: ", "))]"
                    }
                }
            } body: {
                node.visibleChildren(
                    hideEmptyCollections: hideEmptyCollections,
                    hideTokens: hideTokens,
                    hideNonScope: hideNonScope
                ).map { (child) in
                    SyntaxTreeNodeView(
                        node: child,
                        converter: converter,
                        hideEmptyCollections: hideEmptyCollections,
                        hideTokens: hideTokens,
                        hideNonScope: hideNonScope
                    )
                }
            }
        }
    }
}

private struct VisibilityPopover: Component {
    var deps: Deps? {
        [
            hideEmptyCollections, hideTokens, hideNonScope,
            onToggleEmptyCollections, onToggleTokens, onToggleNonScope,
        ]
    }

    let hideEmptyCollections: Bool
    let hideTokens: Bool
    let hideNonScope: Bool
    let onToggleEmptyCollections: EventListener
    let onToggleTokens: EventListener
    let onToggleNonScope: EventListener

    func render() -> Node {
        div(
            style: .init()
                .position("absolute")
                .top("calc(100% + 4px)")
                .right("0")
                .padding("8px 10px")
                .backgroundColor("#fff")
                .border("1px solid #ccc")
                .borderRadius("4px")
                .boxShadow("0 4px 12px rgba(0, 0, 0, 0.1)")
                .display("flex")
                .flexDirection("column")
                .gap("6px")
                .zIndex("1")
        ) {
            VisibilityCheckbox(
                text: "Empty Collections",
                checked: !hideEmptyCollections,
                onToggle: onToggleEmptyCollections
            )
            VisibilityCheckbox(
                text: "Tokens",
                checked: !hideTokens,
                onToggle: onToggleTokens
            )
            VisibilityCheckbox(
                text: "Non-Scope",
                checked: !hideNonScope,
                onToggle: onToggleNonScope
            )
        }
    }
}

private struct VisibilityCheckbox: Component {
    var key: AnyHashable? { text }

    var deps: Deps? {
        [text, checked, onToggle]
    }

    let text: String
    let checked: Bool
    let onToggle: EventListener

    func render() -> Node {
        let attributes: Attributes =
            checked
            ? Attributes(["type": "checkbox", "checked": ""])
            : Attributes(["type": "checkbox"])

        return label(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .alignItems("center")
                .gap("6px")
                .cursor("pointer")
                .userSelect("none")
        ) {
            input(
                attributes: attributes,
                listeners: .init().change(onToggle)
            )
            text
        }
    }
}

internal extension SyntaxProtocol {
    var isScope: Bool {
        Syntax(self).asProtocol(SyntaxProtocol.self) is ScopeSyntax
    }

    var introducedNames: [String] {
        guard
            let scope = Syntax(self).asProtocol(SyntaxProtocol.self) as? ScopeSyntax
        else { return [] }
        return scope.lookupAtScopeEnd().map { $0.identifier.name }
    }

    var introducedNamesToParent: [String] {
        Syntax(self).introducedNameTextsToParent
    }

    // Lift scope descendants of hidden non-scope children up to this level so the
    // visible tree only contains scope nodes while preserving ancestor order.
    func visibleChildren(
        hideEmptyCollections: Bool,
        hideTokens: Bool,
        hideNonScope: Bool
    ) -> [Syntax] {
        children(viewMode: .sourceAccurate).flatMap { (child) -> [Syntax] in
            if hideEmptyCollections,
                child.syntaxNodeType.structure.isCollection,
                child.children(viewMode: .sourceAccurate).isEmpty
            {
                return []
            }

            if hideTokens, child.is(TokenSyntax.self) {
                return []
            }

            if hideNonScope, !child.isScope {
                return child.visibleChildren(
                    hideEmptyCollections: hideEmptyCollections,
                    hideTokens: hideTokens,
                    hideNonScope: hideNonScope
                )
            }

            return [child]
        }
    }
}

private extension SyntaxProtocol {
    var typeName: String {
        let raw = "\(syntaxNodeType)"
        return raw.hasSuffix("Syntax") ? String(raw.dropLast("Syntax".count)) : raw
    }
}
