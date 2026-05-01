import React
import SwiftCodeEditor
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

        let syntax = Parser.parse(source: text)

        return div(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .height("100vh")
                .overflow("hidden")
        ) {
            SwiftCodeEditor(text: text, onInput: onTextChange)
            SwiftSyntaxVisualizeView(syntax: syntax)
            SwiftSyntaxScopeVisualizeView(syntax: syntax)
        }
    }
}

internal struct SwiftSyntaxVisualizeView: Component {
    let syntax: any SyntaxProtocol

    func render() -> Node {
        div(
            style: .init()
                .flex("1 1 0")
                .minWidth("0")
                .height("100%")
                .overflow("auto")
                .padding("8px")
                .borderRight("1px solid #ddd")
                .boxSizing("border-box")
                .whiteSpace("pre-wrap")
        ) {
            syntax.debugDescription
        }
    }
}

internal struct SwiftSyntaxScopeVisualizeView: Component {
    let syntax: SourceFileSyntax

    func render() -> Node {
        div(
            style: .init()
                .flex("1 1 0")
                .minWidth("0")
                .height("100%")
                .overflow("auto")
                .padding("8px")
                .boxSizing("border-box")
                .whiteSpace("pre-wrap")
        ) {
            let scope = SourceFileScope(syntax: syntax)
            let _ = scope.buildFullyExpandedTree()
            scope.dump()
        }
    }
}
