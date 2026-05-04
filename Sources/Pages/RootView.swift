import React
import SwiftCodeEditor
@_spi(Experimental) import SwiftLexicalLookup
import SwiftParser
import SwiftReactPlus
import SwiftSyntax
import SwiftSyntaxScope

public struct RootView: Component {
    @State var text: String = ""
    @State var highlightedRange: Range<AbsolutePosition>? = nil
    @State var lookupConfig: LookupConfig = .default
    @State var lookupResult: LookupResultData? = nil

    @ParseSourceHook var parsed: ParsedSource

    @Callback var onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>
    @Callback var onLookup: Function<Void, ClickPointInfo>
    @Callback var onLookupClose: Function<Void>

    public init() {}

    public func render() -> Node {
        $parsed(text: text)

        $onHoverRangeChange(deps: []) { (range) in
            self.highlightedRange = range
        }

        $onLookup(deps: [parsed.syntax.id, lookupConfig]) { (info) in
            self.lookupResult = parsed.scope.makeLookupResult(
                info: info,
                config: lookupConfig
            )
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
                        text: _text.binding,
                        highlightRange: highlightedRange.map {
                            $0.lowerBound.utf8Offset..<$0.upperBound.utf8Offset
                        },
                        lookupConfig: _lookupConfig.binding,
                        lookupResult: lookupResult,
                        onLookup: onLookup,
                        onHoverRangeChange: onHoverRangeChange,
                        onLookupClose: onLookupClose
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
        }
    }
}
