import React
import SwiftCodeEditor

internal struct SwiftCodeEditorPane: Component {
    let text: String
    let highlightRange: Range<Int>?
    let lookupConfig: LookupConfig
    let onInput: Function<Void, String>
    let onLookup: Function<Void, ClickPointInfo>
    let onLookupConfigChange: Function<Void, LookupConfig>

    @State var isLookupMode: Bool = false
    @Callback var onLookupClick: Function<Void, ClickPointInfo>

    var deps: Deps? {
        [text, highlightRange, lookupConfig, onInput, onLookup, onLookupConfigChange]
    }

    func render() -> Node {
        $onLookupClick(deps: [onLookup]) { (info) in
            onLookup(info)
            isLookupMode = false
        }

        return Pane(
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
                    LookupSettingsButton(
                        config: lookupConfig,
                        onConfigChange: onLookupConfigChange
                    )
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
    }
}
