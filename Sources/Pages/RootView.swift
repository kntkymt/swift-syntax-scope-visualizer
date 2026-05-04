import React
import SRTJavaScriptKitEx
import SwiftCodeEditor
@_spi(Experimental) import SwiftLexicalLookup
import SwiftParser
import SwiftSyntax
import SwiftSyntaxScope

public struct RootView: Component {
    @State var text: String = ""
    @State var parsed: ParsedSource = ParsedSource(from: "")
    @State var highlightedRange: Range<AbsolutePosition>? = nil
    @State var lookupConfig: LookupConfig = .default
    @State var lookupResult: LookupResultData? = nil
    @Effect var parseEffect
    @Callback var onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>
    @Callback var onLookup: Function<Void, ClickPointInfo>
    @Callback var onLookupConfigChange: Function<Void, LookupConfig>
    @Callback var onLookupClose: Function<Void>

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
                parsed = ParsedSource(from: pendingText)
            }

            return {
                _ = timer
            }
        }

        $onHoverRangeChange(deps: []) { (range) in
            self.highlightedRange = range
        }

        $onLookup(deps: [parsed.syntax.id, lookupConfig]) { (info) in
            self.lookupResult = parsed.scope.makeLookupResult(
                info: info,
                config: lookupConfig
            )
        }

        $onLookupConfigChange(deps: []) { (newConfig) in
            self.lookupConfig = newConfig
        }

        $onLookupClose(deps: []) {
            self.lookupResult = nil
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
                        lookupConfig: lookupConfig,
                        onInput: onTextChange,
                        onLookup: onLookup,
                        onLookupConfigChange: onLookupConfigChange
                    )
                    SwiftLexicalLookupPane(
                        syntax: parsed.syntax,
                        highlightedSyntaxIds: lookupResult?.lexicalLookupOriginSyntaxIds ?? [],
                        onHoverRangeChange: onHoverRangeChange
                    )
                    SwiftSyntaxScopePane(
                        scope: parsed.scope,
                        highlightedScopeIds: lookupResult?.syntaxScopeOriginScopeIds ?? [],
                        onHoverRangeChange: onHoverRangeChange
                    )
                }
            }

            if let lookupResult {
                LookupResultPopover(
                    anchorPoint: lookupResult.anchorPoint,
                    sourceLocationDescription: lookupResult.sourceLocationDescription,
                    lexicalLookupNames: lookupResult.lexicalLookupNames,
                    syntaxScopeNames: lookupResult.syntaxScopeNames,
                    onHoverRangeChange: onHoverRangeChange,
                    onClose: onLookupClose
                )
            }
        }
    }
}

struct ParsedSource: Equatable {
    init(from text: String) {
        self.text = text
        let syntax = Parser.parse(source: text)
        self.syntax = syntax
        let scope = SourceFileScope(syntax: syntax)
        scope.buildFullyExpandedTree()
        self.scope = scope
    }

    let text: String
    let syntax: SourceFileSyntax
    let scope: SourceFileScope

    static func == (lhs: ParsedSource, rhs: ParsedSource) -> Bool {
        lhs.text == rhs.text
    }
}
