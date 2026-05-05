@_spi(RawSyntax) import SwiftSyntax
@_spi(Experimental) import SwiftLexicalLookup
import React
import SwiftReactPlus

internal struct SwiftLexicalLookupPane: Component {
    let syntax: (any SyntaxProtocol)?
    let highlightedSyntaxIds: Set<SyntaxIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    @BindableState var config: VisibleNodeConfig = .default

    var deps: Deps? {
        [
            syntax?.id,
            highlightedSyntaxIds,
            onUpdateHighlightedSourceCodeRange,
        ]
    }

    func render() -> Node {
        Pane(
            header: {
                h4(style: .init().margin("0")) { "Swift Lexical Lookup" }

                SettingsButton(config: $config)
            },
            border: .right
        ) {
            if let syntax {
                let converter = SourceLocationConverter(fileName: "", tree: syntax.root)

                div(style: .init().whiteSpace("nowrap")) {
                    SyntaxTreeNodeView(
                        node: syntax,
                        converter: converter,
                        config: config,
                        highlightedSyntaxIds: highlightedSyntaxIds,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
                    )
                }
            }
        }
    }
}

private struct SyntaxTreeNodeView: Component {
    var key: AnyHashable? { node.id }

    var deps: Deps? {
        [
            node.id,
            ObjectIdentifier(converter),
            config,
            highlightedSyntaxIds,
            onUpdateHighlightedSourceCodeRange,
        ]
    }

    let node: any SyntaxProtocol
    let converter: SourceLocationConverter
    let config: SwiftLexicalLookupPane.VisibleNodeConfig
    let highlightedSyntaxIds: Set<SyntaxIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    @Callback var onHoverChange: Function<Void, Bool>

    func render() -> Node {
        // Avoid declaring `scopeDebugName` on `SyntaxProtocol`: it shadows the
        // `ScopeSyntax` requirement of the same name and recurses infinitely.
        let scope = Syntax(node).asProtocol(SyntaxProtocol.self) as? ScopeSyntax
        let typeColor = node.isScope ? Color.red : Color.blue
        let introducedNames = node.introducedNames
        let introducedNamesToParent = node.introducedNamesToParent
        let declNames = node.declNames
        let isLookupOrigin = highlightedSyntaxIds.contains(node.id)

        $onHoverChange(deps: [node.id, onUpdateHighlightedSourceCodeRange]) { (isHovered) in
            onUpdateHighlightedSourceCodeRange(isHovered ? node.trimmedRange : nil)
        }

        return HoverHighlight(onHoverChange: onHoverChange) {
            Accordion(
                headerBackgroundColor:
                    isLookupOrigin ? Color.lookupOriginHighlight : "transparent"
            ) {
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
                            .color(Color.secondary)
                    ) {
                        token.tokenKind == .endOfFile ? ".eof" : "\"\(token.text)\""
                    }
                }

                if !declNames.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color(Color.secondary)
                    ) {
                        declNames.lazy.map { "\"\($0)\"" }.joined(separator: ", ")
                    }
                }

                span(
                    style: .init()
                        .marginLeft("8px")
                        .color(Color.secondary)
                ) {
                    node.sourceRange(converter: converter).description
                }

                if !introducedNames.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color(Color.secondary)
                    ) {
                        "introduces=[\(introducedNames.joined(separator: ", "))]"
                    }
                }

                if !introducedNamesToParent.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color(Color.secondary)
                    ) {
                        "introducesToParent=[\(introducedNamesToParent.joined(separator: ", "))]"
                    }
                }
            } body: {
                node.visibleChildren(config: config).map { (child) in
                    SyntaxTreeNodeView(
                        node: child,
                        converter: converter,
                        config: config,
                        highlightedSyntaxIds: highlightedSyntaxIds,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
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
    func visibleChildren(config: SwiftLexicalLookupPane.VisibleNodeConfig) -> [Syntax] {
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
