import React
import SwiftCodeEditor
import SwiftReactPlus
import SwiftSyntax

internal struct SwiftCodeEditorPane: Component {
    let text: String
    let highlightRange: Range<Int>?
    @Binding var lookupConfig: LookupConfig
    let lookupResult: LookupResultData?
    let onInput: Function<Void, String>
    let onLookup: Function<Void, ClickPointInfo>
    let onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>
    let onLookupClose: Function<Void>

    @State var isLookupMode: Bool = false
    @Callback var onLookupClick: Function<Void, ClickPointInfo>

    var deps: Deps? {
        [
            text, highlightRange, lookupConfig, lookupResult,
            onInput, onLookup,
            onHoverRangeChange, onLookupClose,
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
                    text: text,
                    highlightRange: highlightRange,
                    isClickPointMode: isLookupMode,
                    onInput: onInput,
                    onClickPoint: onLookupClick
                )
            }

            if let lookupResult {
                LookupResultPopover(
                    result: lookupResult,
                    onHoverRangeChange: onHoverRangeChange,
                    onClose: onLookupClose
                )
            }
        }
    }
}
