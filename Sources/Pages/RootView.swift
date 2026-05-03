import React
import SRTJavaScriptKitEx
import SwiftCodeEditor
@_spi(Experimental) import SwiftLexicalLookup
import SwiftParser
import SwiftSyntax
import SwiftSyntaxScope

public struct RootView: Component {

    @State var text: String = ""
    @State var parsed: ParsedSource = .init(text: "", syntax: Parser.parse(source: ""))
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
                parsed = ParsedSource(text: pendingText, syntax: Parser.parse(source: pendingText))
            }

            return {
                _ = timer
            }
        }

        $onHoverRangeChange(deps: []) { (range) in
            self.highlightedRange = range
        }

        $onLookup(deps: [parsed.syntax.id, lookupConfig]) { (info) in
            self.lookupResult = parsed.syntax.makeLookupResult(
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
                        onHoverRangeChange: onHoverRangeChange
                    )
                    SwiftSyntaxScopePane(
                        syntax: parsed.syntax,
                        onHoverRangeChange: onHoverRangeChange
                    )
                }
            }

            if let lookupResult {
                LookupResultPopover(
                    clientX: lookupResult.clientX,
                    clientY: lookupResult.clientY,
                    lexicalLookupNames: lookupResult.lexicalLookupNames,
                    syntaxScopeNames: lookupResult.syntaxScopeNames,
                    onClose: onLookupClose
                )
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

internal struct LookupResultData: Equatable {
    var clientX: Double
    var clientY: Double
    var lexicalLookupNames: [String]
    var syntaxScopeNames: [String]
}

private extension SourceFileSyntax {
    func makeLookupResult(
        info: ClickPointInfo,
        config: LookupConfig
    ) -> LookupResultData {
        let position = AbsolutePosition(utf8Offset: info.utf8Offset)
        let identifier = config.name.asLookupIdentifier
        let lexicalConfig = SwiftLexicalLookup.LookupConfig(
            finishInSequentialScope: config.swiftLexicalLookup.finishInSequentialScope
        )
        let options: LookupOptions =
            config.swiftSyntaxScope.includeOuterResults ? .includeOuterResults : []

        let lexicalLookupNames =
            (token(at: position)?.lookup(identifier, with: lexicalConfig) ?? [])
            .flatMap(\.names)
            .flatMap(\.flattened)
            .map(\.displayDescription)

        let syntaxScopeNames = lexicalLookup(
            position: position,
            name: identifier,
            options: options
        )
        .map { "\($0.kind):\($0.text)" }

        return LookupResultData(
            clientX: info.clientX,
            clientY: info.clientY,
            lexicalLookupNames: lexicalLookupNames,
            syntaxScopeNames: syntaxScopeNames
        )
    }
}

private extension String {
    // Parse the user-entered text as Swift source and pull out the first identifier-like
    // token. Empty / whitespace-only / non-identifier inputs return nil so lookup falls back
    // to "all names at this position".
    var asLookupIdentifier: Identifier? {
        guard !isEmpty else { return nil }
        let parsed = Parser.parse(source: self)
        return parsed.tokens(viewMode: .sourceAccurate)
            .first { $0.tokenKind != .endOfFile }
            .flatMap { Identifier($0) }
    }
}
