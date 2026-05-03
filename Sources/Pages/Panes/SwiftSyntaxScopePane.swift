import React
import SwiftSyntax
import SwiftSyntaxScope

internal struct SwiftSyntaxScopePane: Component {
    let syntax: SourceFileSyntax
    let onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>

    var deps: Deps? {
        [syntax.id, onHoverRangeChange]
    }

    func render() -> Node {
        let scope = SourceFileScope(syntax: syntax)
        scope.buildFullyExpandedTree()

        return Pane(
            title: "Swift Syntax Scope (referencing swift compiler)",
            border: [],
        ) {
            div(style: .init().whiteSpace("nowrap")) {
                ScopeTreeNodeView(
                    scope: scope,
                    onHoverRangeChange: onHoverRangeChange
                )
            }
        }
    }
}

private struct ScopeTreeNodeView: Component {
    var key: AnyHashable? { ObjectIdentifier(scope) }

    let scope: any SyntaxScopeProtocol
    let onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>

    @Callback var onHoverChange: Function<Void, Bool>

    func render() -> Node {
        let names = scope.introducedLookupNames

        $onHoverChange(deps: [ObjectIdentifier(scope), onHoverRangeChange]) { (isHovered) in
            onHoverRangeChange(isHovered ? scope.range : nil)
        }

        return HoverHighlight(onHoverChange: onHoverChange) {
            Accordion {
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
                        onHoverRangeChange: onHoverRangeChange
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
