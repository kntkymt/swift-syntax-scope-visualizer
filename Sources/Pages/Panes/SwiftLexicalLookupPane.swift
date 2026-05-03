@_spi(RawSyntax) import SwiftSyntax
@_spi(Experimental) import SwiftLexicalLookup
import React

internal struct LexicalLookupConfig: Hashable {
    var hideEmptyCollections: Bool = true
    var hideTokens: Bool = true
    var hideNonScope: Bool = false

    var isFiltered: Bool {
        hideEmptyCollections || hideTokens || hideNonScope
    }
}

internal struct SwiftLexicalLookupPane: Component {
    let syntax: any SyntaxProtocol

    @State var config: LexicalLookupConfig = .init()
    @State var isPopoverOpen: Bool = false

    var deps: Deps? {
        [syntax.id]
    }

    func render() -> Node {
        let converter = SourceLocationConverter(fileName: "", tree: syntax.root)

        let onTogglePopover = EventListener { _ in
            isPopoverOpen.toggle()
        }
        let onToggleEmptyCollections = EventListener { _ in
            config.hideEmptyCollections.toggle()
        }
        let onToggleTokens = EventListener { _ in
            config.hideTokens.toggle()
        }
        let onToggleNonScope = EventListener { _ in
            config.hideNonScope.toggle()
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
                            .backgroundColor(config.isFiltered ? "#495057" : "#fff")
                            .color(config.isFiltered ? "#fff" : "#000")
                            .cursor("pointer")
                            .font("inherit"),
                        listeners: .init().click(onTogglePopover)
                    ) {
                        "Settings"
                    }

                    if isPopoverOpen {
                        SettingsPopover(
                            config: config,
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
                    config: config
                )
            }
        }
    }
}

private struct SyntaxTreeNodeView: Component {
    var key: AnyHashable? { node.id }

    var deps: Deps? {
        [node.id, ObjectIdentifier(converter), config]
    }

    let node: any SyntaxProtocol
    let converter: SourceLocationConverter
    let config: LexicalLookupConfig

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
                node.visibleChildren(config: config).map { (child) in
                    SyntaxTreeNodeView(
                        node: child,
                        converter: converter,
                        config: config
                    )
                }
            }
        }
    }
}

private struct SettingsPopover: Component {
    var deps: Deps? {
        [
            config,
            onToggleEmptyCollections, onToggleTokens, onToggleNonScope,
        ]
    }

    let config: LexicalLookupConfig
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
                .whiteSpace("nowrap")
                .zIndex("1")
        ) {
            SettingsCheckbox(
                text: "Hide Empty Collections",
                checked: config.hideEmptyCollections,
                onToggle: onToggleEmptyCollections
            )
            SettingsCheckbox(
                text: "Hide Tokens",
                checked: config.hideTokens,
                onToggle: onToggleTokens
            )
            SettingsCheckbox(
                text: "Hide Non-Scope",
                checked: config.hideNonScope,
                onToggle: onToggleNonScope
            )
        }
    }
}

private struct SettingsCheckbox: Component {
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
        return scope.lookupAtScopeEnd().flatMap(\.flattened).map(\.displayDescription)
    }

    var introducedNamesToParent: [String] {
        Syntax(self).introducedNameTextsToParent
    }

    // Lift scope descendants of hidden non-scope children up to this level so the
    // visible tree only contains scope nodes while preserving ancestor order.
    func visibleChildren(config: LexicalLookupConfig) -> [Syntax] {
        children(viewMode: .sourceAccurate).flatMap { (child) -> [Syntax] in
            if config.hideEmptyCollections,
                child.syntaxNodeType.structure.isCollection,
                child.children(viewMode: .sourceAccurate).isEmpty
            {
                return []
            }

            if config.hideTokens, child.is(TokenSyntax.self) {
                return []
            }

            if config.hideNonScope, !child.isScope {
                return child.visibleChildren(config: config)
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
