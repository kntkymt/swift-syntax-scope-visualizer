import React
import SwiftCodeEditor

internal struct SwiftCodeEditorPane: Component {
    let text: String
    let highlightRange: Range<Int>?
    let onInput: Function<Void, String>
    let onLookup: Function<Void, ClickPointInfo>

    @State var isLookupMode: Bool = false
    @Callback var onLookupClick: Function<Void, ClickPointInfo>

    var deps: Deps? {
        [text, highlightRange, onInput, onLookup]
    }

    func render() -> Node {
        $onLookupClick(deps: [onLookup]) { (info) in
            onLookup(info)
            isLookupMode = false
        }

        return Pane(
            header: {
                h4(style: .init().margin("0")) { "Source Code" }

                LookupButton(
                    isActive: isLookupMode,
                    onClick: Function { isLookupMode.toggle() }
                )
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

private struct LookupButton: Component {
    var deps: Deps? {
        [isActive, onClick]
    }

    let isActive: Bool
    let onClick: Function<Void>

    func render() -> Node {
        button(
            style: .init()
                .padding("4px 10px")
                .border("1px solid #ccc")
                .borderRadius("4px")
                .backgroundColor(isActive ? "#e0ebff" : "#fff")
                .color("#000")
                .cursor("pointer")
                .font("inherit"),
            listeners: .init().click(EventListener { _ in onClick() })
        ) {
            "Lookup"
        }
    }
}
