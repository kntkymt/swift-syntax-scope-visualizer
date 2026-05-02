import React
import SRTJavaScriptKitEx
import SwiftCodeEditor
import SwiftParser
import SwiftSyntax

public struct RootView: Component {

    @State var text: String = ""
    @State var parsed: ParsedSource = .init(text: "", syntax: Parser.parse(source: ""))
    @Effect var parseEffect

    public init() {}

    public func render() -> Node {
        let onTextChange = EventListener { (event) in
            let text = try! String.mustConstruct(from: event.jsValue.target.value)
            self.text = text
        }

        // Debounce text -> SourceFileSyntax. Cleanup captures `timer` so that
        // dropping the closure releases the JSTimer, triggering clearTimeout
        // via its deinit.
        $parseEffect(deps: [text]) {
            let pendingText = text
            let timer = JSTimer(millisecondsDelay: 500) {
                parsed = ParsedSource(text: pendingText, syntax: Parser.parse(source: pendingText))
            }

            return {
                _ = timer
            }
        }

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
            SwiftSyntaxView(syntax: parsed.syntax)
            SwiftSyntaxScopeVisualizeView(syntax: parsed.syntax)
        }
    }
}

struct ParsedSource: Equatable {
    let text: String
    let syntax: SourceFileSyntax

    static func == (lhs: ParsedSource, rhs: ParsedSource) -> Bool {
        lhs.text == rhs.text
    }
}
