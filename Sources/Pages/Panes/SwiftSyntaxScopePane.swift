import React
import SwiftSyntax
import SwiftSyntaxScope

internal struct SwiftSyntaxScopePane: Component {
    let syntax: SourceFileSyntax

    var deps: Deps? {
        [syntax.id]
    }

    func render() -> Node {
        let scope = SourceFileScope(syntax: syntax)
        scope.buildFullyExpandedTree()

        return Pane(
            title: "Swift Syntax Scope (referencing swift compiler)",
            showRightBorder: false
        ) {
            div(style: .init().whiteSpace("nowrap")) {
                ScopeTreeNodeView(scope: scope)
            }
        }
    }
}

private struct ScopeTreeNodeView: Component {
    var key: AnyHashable? { ObjectIdentifier(scope) }

    let scope: any SyntaxScopeProtocol

    func render() -> Node {
        let names = scope.introducedLookupNames

        return HoverHighlight {
            Accordion {
                span(style: .init().color("#c92a2a")) {
                    scope.scopeTypeDescription
                }

                span(
                    style: .init()
                        .marginLeft("8px")
                        .color("#666")
                ) {
                    scope.sourceRangeDescription
                }

                if !names.isEmpty {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color("#666")
                    ) {
                        "introduces=[\(names.map(\.text).joined(separator: ", "))]"
                    }
                }
            } body: {
                scope.children.map { (child) in
                    ScopeTreeNodeView(scope: child)
                }
            }
        }
    }
}

private extension SyntaxScopeProtocol {
    var sourceRangeDescription: String {
        sourceRange.description(converter: sourceLocationConverter)
    }
}
