import React
import SwiftSyntax
import SwiftSyntaxScope

internal struct SwiftSyntaxScopePane: Component {
    let scope: SourceFileScope
    let highlightedScopeIds: Set<ObjectIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    var deps: Deps? {
        [
            ObjectIdentifier(scope),
            highlightedScopeIds,
            onUpdateHighlightedSourceCodeRange,
        ]
    }

    func render() -> Node {
        Pane(
            title: "Swift Syntax Scope (referencing swift compiler)",
            border: [],
        ) {
            div(style: .init().whiteSpace("nowrap")) {
                ScopeTreeNodeView(
                    scope: scope,
                    highlightedScopeIds: highlightedScopeIds,
                    onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
                )
            }
        }
    }
}

private struct ScopeTreeNodeView: Component {
    var key: AnyHashable? { ObjectIdentifier(scope) }

    let scope: any SyntaxScopeProtocol
    let highlightedScopeIds: Set<ObjectIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    var deps: Deps? {
        [
            ObjectIdentifier(scope),
            highlightedScopeIds,
            onUpdateHighlightedSourceCodeRange,
        ]
    }

    @Callback var onHoverChange: Function<Void, Bool>

    func render() -> Node {
        let names = scope.introducedLookupNames
        let isLookupOrigin = highlightedScopeIds.contains(ObjectIdentifier(scope))

        $onHoverChange(deps: [ObjectIdentifier(scope), onUpdateHighlightedSourceCodeRange]) {
            (isHovered) in
            onUpdateHighlightedSourceCodeRange(isHovered ? scope.range : nil)
        }

        return HoverHighlight(onHoverChange: onHoverChange) {
            Accordion(
                headerBackgroundColor:
                    isLookupOrigin ? Color.lookupOriginHighlight : "transparent"
            ) {
                span(style: .init().color(Color.red)) {
                    scope.scopeTypeDescription
                }

                if !scope.syntax.declNames.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color(Color.secondary)
                    ) {
                        scope.syntax.declNames.lazy.map { "\"\($0)\"" }.joined(separator: ", ")
                    }
                }

                span(
                    style: .init()
                        .marginLeft("8px")
                        .color(Color.secondary)
                ) {
                    scope.rangeDescription
                }

                if !names.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color(Color.secondary)
                    ) {
                        "introduces=[\(names.map { "\($0.kind):\($0.text)" }.joined(separator: ", "))]"
                    }
                }
            } body: {
                scope.children.map { (child) in
                    ScopeTreeNodeView(
                        scope: child,
                        highlightedScopeIds: highlightedScopeIds,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
                    )
                }
            }
        }
    }
}

private extension SyntaxScopeProtocol {
    var rangeDescription: String {
        let converter = SourceLocationConverter(fileName: "", tree: syntax.root)
        return sourceRange(converter: converter).description
    }
}
