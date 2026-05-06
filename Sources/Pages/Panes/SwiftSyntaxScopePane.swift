import React
import SwiftReactPlus
import SwiftSyntax
import SwiftSyntaxScope

internal struct SwiftSyntaxScopePane: Component {
    let scope: SourceFileScope?
    let converter: SourceLocationConverter?
    let highlights: TreeNodeHighlights<ObjectIdentifier>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    @BindableState var isCollapsed: Bool = true

    var deps: Deps? {
        [
            scope?.id,
            converter,
            highlights,
            onUpdateHighlightedSourceCodeRange,
        ]
    }

    func render() -> Node {
        if isCollapsed {
            return CollapsedSwiftSyntaxScopePane(isCollapsed: $isCollapsed)
        }

        return Pane(
            header: {
                div(
                    style: .init()
                        .display("flex")
                        .flexDirection("row")
                        .alignItems("center")
                        .gap("8px")
                ) {
                    Button(onClick: Function { isCollapsed = true }) {
                        "→"
                    }

                    h4(style: .init().margin("0")) {
                        "Swift Syntax Scope (referencing swift compiler)"
                    }
                }
            },
            border: []
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

private struct CollapsedSwiftSyntaxScopePane: Component {
    @Binding var isCollapsed: Bool

    var deps: Deps? {
        [_isCollapsed]
    }

    func render() -> Node {
        div(
            style: .init()
                .flex("0 0 auto")
                .width("44px")
                .height("100%")
                .display("flex")
                .flexDirection("column")
                .boxSizing("border-box")
                .fontFamily("system-ui, -apple-system, BlinkMacSystemFont, sans-serif")
        ) {
            div(
                style: .init()
                    .height("44px")
                    .flexShrink("0")
                    .boxSizing("border-box")
                    .borderBottom("1px solid #ddd")
                    .backgroundColor("#f5f5f5")
                    .display("flex")
                    .alignItems("center")
                    .justifyContent("center")
            ) {
                Button(onClick: Function { isCollapsed = false }) {
                    "←"
                }
            }

            div(
                style: .init()
                    .flex("1 1 0")
                    .display("flex")
                    .alignItems("center")
                    .justifyContent("center")
                    .padding("8px 0")
            ) {
                span(
                    style: .init()
                        .writingMode("vertical-rl")
                        .whiteSpace("nowrap")
                ) {
                    "Swift Syntax Scope"
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
