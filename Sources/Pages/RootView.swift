import React
import SwiftCodeEditor
import SwiftParser

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
            Pane(scrollable: false) {
                SwiftCodeEditor(text: text, onInput: onTextChange)
            }
            SwiftSyntaxView(syntax: syntax)
            SwiftSyntaxScopeVisualizeView(syntax: syntax)
        }
    }
}
