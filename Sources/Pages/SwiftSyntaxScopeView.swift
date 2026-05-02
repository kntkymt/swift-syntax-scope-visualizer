import React
import SwiftSyntax
import SwiftSyntaxScope

internal struct SwiftSyntaxScopeVisualizeView: Component {
    let syntax: SourceFileSyntax

    func render() -> Node {
        let scope = SourceFileScope(syntax: syntax)
        scope.buildFullyExpandedTree()

        return Pane(showRightBorder: false) {
            ScopeTreeNodeView(scope: scope)
        }
    }
}

internal struct ScopeTreeNodeView: Component {
    var key: AnyHashable? { scope.syntax.id }

    let scope: any SyntaxScopeProtocol

    func render() -> Node {
        let names = scope.introducedLookupNames

        return HoverHighlight {
            Accordion {
                span(style: .init().color("#0a66c2")) {
                    scope.description
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
