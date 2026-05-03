@_spi(RawSyntax) import SwiftSyntax
@_spi(Experimental) import SwiftLexicalLookup
import React

internal struct LexicalLookupConfig: Hashable {
    static var `default`: LexicalLookupConfig {
        LexicalLookupConfig(
            hideEmptyCollections: true,
            hideTokens: true,
            hideNonScope: false
        )
    }

    var hideEmptyCollections: Bool
    var hideTokens: Bool
    var hideNonScope: Bool
}

private extension LexicalLookupConfig {
    var isFiltered: Bool {
        hideEmptyCollections || hideTokens || hideNonScope
    }
}

internal struct SwiftLexicalLookupPane: Component {
    let syntax: any SyntaxProtocol

    @State var config: LexicalLookupConfig = .default
    @Callback var onConfigChange: Function<Void, LexicalLookupConfig>

    var deps: Deps? {
        [syntax.id]
    }

    func render() -> Node {
        let converter = SourceLocationConverter(fileName: "", tree: syntax.root)

        $onConfigChange(deps: []) { (newConfig) in
            config = newConfig
        }

        return Pane(
            header: {
                h4(style: .init().margin("0")) { "Swift Lexical Lookup" }

                SettingsButton(
                    config: config,
                    onConfigChange: onConfigChange
                )
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

private struct SettingsButton: Component {
    var deps: Deps? {
        [config, onConfigChange]
    }

    let config: LexicalLookupConfig
    let onConfigChange: Function<Void, LexicalLookupConfig>

    @State private var isPopoverOpen: Bool = false

    func render() -> Node {
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
                listeners: .init().click(
                    EventListener { _ in
                        isPopoverOpen.toggle()
                    }
                )
            ) {
                "Settings"
            }

            if isPopoverOpen {
                Popover {
                    CheckBoxRow(
                        text: "Hide Empty Collections",
                        checked: config.hideEmptyCollections,
                        onToggle: Function { toggle(\.hideEmptyCollections) }
                    )
                    CheckBoxRow(
                        text: "Hide Tokens",
                        checked: config.hideTokens,
                        onToggle: Function { toggle(\.hideTokens) }
                    )
                    CheckBoxRow(
                        text: "Hide Non-Scope",
                        checked: config.hideNonScope,
                        onToggle: Function { toggle(\.hideNonScope) }
                    )
                }
            }
        }
    }
}

private extension SettingsButton {
    func toggle(_ keyPath: WritableKeyPath<LexicalLookupConfig, Bool>) {
        var newConfig = config
        newConfig[keyPath: keyPath].toggle()
        onConfigChange(newConfig)
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
                    node.sourceRange(converter: converter).description
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
