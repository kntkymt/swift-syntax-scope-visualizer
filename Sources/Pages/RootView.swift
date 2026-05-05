import React
import SwiftCodeEditor
@_spi(Experimental) import SwiftLexicalLookup
import SwiftParser
import SwiftReactPlus
import SwiftSyntax
import SwiftSyntaxScope

public struct RootView: Component {
    @BindableState var sourceCode: String = ""
    @BindableState var highlightedSourceCodeRange: Range<AbsolutePosition>? = nil
    @BindableState var lookupConfig: LookupConfig = .default

    @ParseSourceHook var parsed: ParsedSource
    @LookupHook var lookupResult: LookupResultData?

    public init() {}

    public func render() -> Node {
        $parsed(sourceCode: sourceCode)
        $lookupResult(scope: parsed.scope, config: lookupConfig)

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
                        sourceCode: $sourceCode,
                        lookupConfig: $lookupConfig,
                        highlightedSourceCodeRange: $highlightedSourceCodeRange,
                        lookupResult: lookupResult,
                        onLookup: $lookupResult.onLookup,
                        onLookupClose: $lookupResult.onLookupClose
                    )
                    SwiftLexicalLookupPane(
                        syntax: parsed.syntax,
                        highlightedSyntaxIds: lookupResult?.lexicalLookupOriginSyntaxIds ?? [],
                        onUpdateHighlightedSourceCodeRange: $highlightedSourceCodeRange.setValue
                    )
                    SwiftSyntaxScopePane(
                        scope: parsed.scope,
                        highlightedScopeIds: lookupResult?.syntaxScopeOriginScopeIds ?? [],
                        onUpdateHighlightedSourceCodeRange: $highlightedSourceCodeRange.setValue
                    )
                }
            }
        }
    }
}
