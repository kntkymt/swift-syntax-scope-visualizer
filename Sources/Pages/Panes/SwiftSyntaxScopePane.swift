import React
import SwiftSyntax
import SwiftSyntaxScope

internal struct SwiftSyntaxScopePane: Component {
    let scope: SourceFileScope?
    let converter: SourceLocationConverter?
    let highlights: TreeNodeHighlights<ObjectIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    var deps: Deps? {
        [
            scope?.id,
            converter,
            highlights,
            onUpdateHighlightedSourceCodeRange,
        ]
    }

    func render() -> Node {
        Pane(
            title: "Swift Syntax Scope (referencing swift compiler)",
            border: [],
        ) {
            if let scope, let converter {
                div(style: .init().whiteSpace("nowrap")) {
                    ScopeTreeNodeView(
                        scope: scope,
                        converter: converter,
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
    let converter: SourceLocationConverter
    let highlights: TreeNodeHighlights<ObjectIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    @Callback var onHoverChange: Function<Void, Bool>

    var deps: Deps? {
        [
            scope.id,
            converter,
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
                ScopeTreeNodeRowView(scope: scope, converter: converter)
            } body: {
                scope.children.map { (child) in
                    ScopeTreeNodeView(
                        scope: child,
                        converter: converter,
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
    let converter: SourceLocationConverter

    var deps: Deps? {
        [scope.id, converter]
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
                scope.sourceRange(converter: converter).description
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
