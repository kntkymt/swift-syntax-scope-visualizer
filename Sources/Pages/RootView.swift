import React
import SwiftParser
import SwiftSyntax
import SwiftSyntaxScope

public struct RootView: Component {

    @State var text: String = ""

    public init() {}

    public func render() -> Node {
        let onTextChange = EventListener { (event) in
            let text = try! String.mustConstruct(from: event.jsValue.target.value)
            self.text = text
        }

        return div(
            style: .init()
                .display("flex")
                .flexDirection("row")
        ) {
            textarea(
                attributes: .init()
                    .rows("4")
                    .placeholder("input your string here"),
                style: .init()
                    .margin("0px 16px"),
                listeners: .init()
                    .input(onTextChange)
            )

            let syntax = Parser.parse(source: text)
            SwiftSyntaxVisualizeView(syntax: syntax)
            SwiftSyntaxScopeVisualizeView(syntax: syntax)
        }
    }
}

internal struct SwiftSyntaxVisualizeView: Component {
    let syntax: any SyntaxProtocol

    func render() -> Node {
        div(style: .init().whiteSpace("pre-wrap")) {
            syntax.debugDescription
        }
    }
}

internal struct SwiftSyntaxScopeVisualizeView: Component {
    let syntax: SourceFileSyntax

    func render() -> Node {
        div(style: .init().whiteSpace("pre-wrap")) {
            let scope = SourceFileScope(syntax: syntax)
            let _ = scope.buildFullyExpandedTree()
            scope.dump()
        }
    }
}
