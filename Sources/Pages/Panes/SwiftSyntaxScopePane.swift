import React
import SwiftSyntax
import SwiftSyntaxScope

internal struct SwiftSyntaxScopePane: Component {
    let scope: SourceFileScope?
    let highlights: TreeNodeHighlights<ObjectIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    var deps: Deps? {
        [
            scope?.id,
            highlights,
            onUpdateHighlightedSourceCodeRange,
        ]
    }

    func render() -> Node {
        Pane(
            title: "Swift Syntax Scope (referencing swift compiler)",
            border: [],
        ) {
            if let scope {
                div(style: .init().whiteSpace("nowrap")) {
                    ScopeTreeNodeView(
                        scope: scope,
                        highlights: highlights,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
                    )
                }
            }
        }
    }
}

private struct ScopeTreeNodeView: Component {
    var key: AnyHashable? { scope.id }

    let scope: any SyntaxScopeProtocol
    let highlights: TreeNodeHighlights<ObjectIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    @Callback var onHoverChange: Function<Void, Bool>

    var deps: Deps? {
        [
            scope.id,
            highlights,
            onUpdateHighlightedSourceCodeRange,
        ]
    }

    func render() -> Node {
        $onHoverChange(deps: [scope.id, onUpdateHighlightedSourceCodeRange]) {
            (isHovered) in
            onUpdateHighlightedSourceCodeRange(isHovered ? scope.range : nil)
        }

        return HoverHighlight(onHoverChange: onHoverChange) {
            Accordion(
                headerBackgroundColor: highlights.color(for: scope.id)
                    ?? "transparent"
            ) {
                ScopeTreeNodeRowView(scope: scope)
            } body: {
                scope.children.map { (child) in
                    ScopeTreeNodeView(
                        scope: child,
                        highlights: highlights,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
                    )
                }
            }
        }
    }
}

// Header content extracted as its own Component so its deps stay independent
// from `highlights`. When only the header background color changes, the row's
// span content is reused instead of re-rendering.
private struct ScopeTreeNodeRowView: Component {
    let scope: any SyntaxScopeProtocol

    var deps: Deps? {
        [scope.id]
    }

    func render() -> Node {
        let localNames = scope.introducedLocalLookupNames
        let memberNames = scope.introducedMemberLookupNames

        return Fragment {
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

            if !localNames.isEmpty {
                span(
                    style: .init()
                        .marginLeft("8px")
                        .color(Color.secondary)
                ) {
                    "introduces=[\(localNames.map { "\($0.kind):\($0.text)" }.joined(separator: ", "))]"
                }
            }

            if !memberNames.isEmpty {
                span(
                    style: .init()
                        .marginLeft("8px")
                        .color(Color.secondary)
                ) {
                    "introducesMembers=[\(memberNames.map { "\($0.kind):\($0.text)" }.joined(separator: ", "))]"
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
