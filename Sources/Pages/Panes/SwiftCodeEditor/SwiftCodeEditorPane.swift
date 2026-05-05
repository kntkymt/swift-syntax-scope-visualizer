import React
import SwiftCodeEditor
import SwiftReactPlus
import SwiftSyntax

internal struct SwiftCodeEditorPane: Component {
    @Binding var sourceCode: String
    @Binding var lookupConfig: LookupConfig
    @Binding var highlightedSourceCodeRange: Range<AbsolutePosition>?

    let lookupResult: LookupResultData?
    let onLookup: Function<Void, ClickPointInfo>
    let onLookupClose: Function<Void>

    @State var isLookupMode: Bool = false
    @Callback var onLookupClick: Function<Void, ClickPointInfo>

    var deps: Deps? {
        [
            _sourceCode,
            _lookupConfig,
            _highlightedSourceCodeRange,
            lookupResult,
            onLookup,
            onLookupClose,
        ]
    }

    func render() -> Node {
        $onLookupClick(deps: [onLookup]) { (info) in
            onLookup(info)
            isLookupMode = false
        }

        return Fragment {
            Pane(
                header: {
                    h4(style: .init().margin("0")) { "Source Code" }

                    div(
                        style: .init()
                            .display("flex")
                            .flexDirection("row")
                            .gap("8px")
                    ) {
                        Button(
                            isActive: isLookupMode,
                            onClick: Function { isLookupMode.toggle() }
                        ) {
                            isLookupMode ? "Lookup Mode: ON" : "Lookup Mode: OFF"
                        }
                        LookupSettingsButton(config: _lookupConfig)
                    }
                },
                border: .right,
                scrollable: false
            ) {
                SwiftCodeEditor(
                    text: _sourceCode,
                    highlightedRange: highlightedSourceCodeRange.map {
                        $0.lowerBound.utf8Offset..<$0.upperBound.utf8Offset
                    },
                    isClickPointMode: isLookupMode,
                    onClickPoint: onLookupClick
                )
            }

            if let lookupResult {
                LookupResultPopover(
                    result: lookupResult,
                    onUpdateHighlightedSourceCodeRange: _highlightedSourceCodeRange.setValue,
                    onClose: onLookupClose
                )
            }
        }
    }
}
