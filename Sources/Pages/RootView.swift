import React
import SwiftCodeEditor
@_spi(Experimental) import SwiftLexicalLookup
import SwiftParser
import SwiftReactPlus
import SwiftSyntax
import SwiftSyntaxScope

public struct RootView: Component {
    @BindableState var sourceCode: String = Constant.initialSourceCode
    @BindableState var highlightedSourceCodeRange: Range<AbsolutePosition>? = nil
    @BindableState var hoveredLookupSyntaxIds: Set<SyntaxIdentifier> = []
    @BindableState var hoveredLookupScopeIds: Set<ObjectIdentifier> = []
    @BindableState var lookupConfig: LookupConfig = .default
    @BindableState var showLicenses: Bool = false

    @ParseSourceHook var parsed: ParsedSource?
    @LookupHook var lookupResult: LookupResultData?

    @Callback var onLookupClose: Function<Void>

    public init() {}

    public func render() -> Node {
        $parsed(sourceCode: sourceCode)
        $lookupResult(parsed: parsed, config: lookupConfig)

        $onLookupClose(deps: [$lookupResult.onLookupClose]) {
            $lookupResult.onLookupClose()
            hoveredLookupSyntaxIds = []
            hoveredLookupScopeIds = []
        }

        let lexicalLookupHighlights = TreeNodeHighlights<SyntaxIdentifier>([
            .init(ids: hoveredLookupSyntaxIds, color: Color.lookupHoverHighlight),
            .init(
                ids: lookupResult?.lexicalLookupOriginSyntaxIds ?? [],
                color: Color.lookupOriginHighlight
            ),
        ])
        let syntaxScopeHighlights = TreeNodeHighlights<ObjectIdentifier>([
            .init(ids: hoveredLookupScopeIds, color: Color.lookupHoverHighlight),
            .init(
                ids: lookupResult?.syntaxScopeOriginScopeIds ?? [],
                color: Color.lookupOriginHighlight
            ),
        ])

        return div(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .height("100vh")
                .overflow("hidden")
        ) {
            if showLicenses {
                LicensesPane(showLicenses: $showLicenses)
            } else {
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

                            Button(onClick: Function { showLicenses = true }) {
                                "Licenses"
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
                            onLookupClose: onLookupClose,
                            onUpdateHoveredSyntaxIds: $hoveredLookupSyntaxIds.setValue,
                            onUpdateHoveredScopeIds: $hoveredLookupScopeIds.setValue
                        )
                        SwiftLexicalLookupPane(
                            syntax: parsed?.syntax,
                            converter: parsed?.converter,
                            highlights: lexicalLookupHighlights,
                            onUpdateHighlightedSourceCodeRange: $highlightedSourceCodeRange.setValue
                        )
                        SwiftSyntaxScopePane(
                            scope: parsed?.scope,
                            converter: parsed?.converter,
                            highlights: syntaxScopeHighlights,
                            onUpdateHighlightedSourceCodeRange: $highlightedSourceCodeRange.setValue
                        )
                    }
                }
            }
        }
    }
}
