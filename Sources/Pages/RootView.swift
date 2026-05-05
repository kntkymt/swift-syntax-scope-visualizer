import React
import SwiftCodeEditor
@_spi(Experimental) import SwiftLexicalLookup
import SwiftParser
import SwiftReactPlus
import SwiftSyntax
import SwiftSyntaxScope

enum Constant {
    static let initialSourceCode = """
        func f() {
            let a = 1
            if let b = value() {
                let c = 3
            }

            guard let d = value() else {
                let e = 4
            }
            let f = 5
        }
        """

    static let githubURL = "https://github.com/kntkymt/swift-syntax-scope-visualizer"
}

public struct RootView: Component {
    @BindableState var sourceCode: String = Constant.initialSourceCode
    @BindableState var highlightedSourceCodeRange: Range<AbsolutePosition>? = nil
    @BindableState var lookupConfig: LookupConfig = .default

    @ParseSourceHook var parsed: ParsedSource?
    @LookupHook var lookupResult: LookupResultData?

    public init() {}

    public func render() -> Node {
        $parsed(sourceCode: sourceCode)
        $lookupResult(scope: parsed?.scope, config: lookupConfig)

        return div(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .height("100vh")
                .overflow("hidden")
        ) {
            Pane(
                header: {
                    div(
                        style: .init()
                            .display("flex")
                            .flexDirection("row")
                            .alignItems("center")
                            .gap("8px")
                    ) {
                        h4(style: .init().margin("0")) { "Swift Syntax Scope Visualizer" }

                        Button(href: Constant.githubURL) {
                            "GitHub"
                        }
                    }
                },
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
                        syntax: parsed?.syntax,
                        highlightedSyntaxIds: lookupResult?.lexicalLookupOriginSyntaxIds ?? [],
                        onUpdateHighlightedSourceCodeRange: $highlightedSourceCodeRange.setValue
                    )
                    SwiftSyntaxScopePane(
                        scope: parsed?.scope,
                        highlightedScopeIds: lookupResult?.syntaxScopeOriginScopeIds ?? [],
                        onUpdateHighlightedSourceCodeRange: $highlightedSourceCodeRange.setValue
                    )
                }
            }
        }
    }
}
