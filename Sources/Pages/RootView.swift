import React
import SRTJavaScriptKitEx
import SwiftParser
import SwiftSyntax

public struct RootView: Component {

    @State var text: String = ""
    @State var parsed: ParsedSource = .init(text: "", syntax: Parser.parse(source: ""))
    @State var highlightedRange: Range<AbsolutePosition>? = nil
    @Effect var parseEffect
    @Callback var onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>

    public init() {}

    public func render() -> Node {
        let onTextChange = Function<Void, String> { (text) in
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

        $onHoverRangeChange(deps: []) { (range) in
            self.highlightedRange = range
        }

        return div(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .height("100vh")
                .overflow("hidden")
        ) {
            Pane(
                title: "Swift Syntax Scope Visualizer",
                border: [],
                scrollable: false
            ) {
                div(
                    style: .init()
                        .display("flex")
                        .flexDirection("row")
                        .height("100%")
                ) {
                    SwiftCodeEditorPane(
                        text: text,
                        highlightRange: highlightedRange.map {
                            $0.lowerBound.utf8Offset..<$0.upperBound.utf8Offset
                        },
                        onInput: onTextChange
                    )
                    SwiftLexicalLookupPane(
                        syntax: parsed.syntax,
                        onHoverRangeChange: onHoverRangeChange
                    )
                    SwiftSyntaxScopePane(
                        syntax: parsed.syntax,
                        onHoverRangeChange: onHoverRangeChange
                    )
                }
            }
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
