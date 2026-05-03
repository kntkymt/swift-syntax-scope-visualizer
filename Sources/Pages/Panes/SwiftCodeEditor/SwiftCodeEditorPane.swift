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
                    LookupButton(
                        isActive: isLookupMode,
                        onClick: Function { isLookupMode.toggle() }
                    )
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

private struct LookupSettingsButton: Component {
    var deps: Deps? {
        [config, onConfigChange]
    }

    let config: LookupConfig
    let onConfigChange: Function<Void, LookupConfig>

    @State private var isPopoverOpen: Bool = false

    func render() -> Node {
        div(style: .init().position("relative")) {
            button(
                style: .init()
                    .padding("4px 10px")
                    .border("1px solid #ccc")
                    .borderRadius("4px")
                    .backgroundColor("#fff")
                    .color("#000")
                    .cursor("pointer")
                    .font("inherit"),
                listeners: .init().click(
                    EventListener { _ in isPopoverOpen.toggle() }
                )
            ) {
                "Lookup Settings"
            }

            if isPopoverOpen {
                Popover {
                    NameInputRow(
                        name: config.name,
                        onChange: Function { newName in
                            update { $0.name = newName }
                        }
                    )

                    GroupHeader(title: "Swift Lexical Lookup")
                    CheckBoxRow(
                        text: "Finish in sequential scope",
                        checked: config.swiftLexicalLookup.finishInSequentialScope,
                        onToggle: Function {
                            update { $0.swiftLexicalLookup.finishInSequentialScope.toggle() }
                        }
                    )

                    GroupHeader(title: "Swift Syntax Scope")
                    CheckBoxRow(
                        text: "Include outer results",
                        checked: config.swiftSyntaxScope.includeOuterResults,
                        onToggle: Function {
                            update { $0.swiftSyntaxScope.includeOuterResults.toggle() }
                        }
                    )
                }
            }
        }
    }
}

private extension LookupSettingsButton {
    func update(_ mutate: (inout LookupConfig) -> Void) {
        var newConfig = config
        mutate(&newConfig)
        onConfigChange(newConfig)
    }
}

private struct NameInputRow: Component {
    var deps: Deps? {
        [name, onChange]
    }

    let name: String
    let onChange: Function<Void, String>

    func render() -> Node {
        label(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .alignItems("center")
                .gap("6px")
                .userSelect("none")
        ) {
            "Name"
            input(
                attributes: .init()
                    .type("text")
                    .value(name)
                    .placeholder("(any)"),
                style: .init()
                    .font("inherit")
                    .padding("2px 6px")
                    .border("1px solid #ccc")
                    .borderRadius("3px"),
                listeners: .init().input(
                    EventListener { event in
                        let value = String.unsafeConstruct(from: event.jsValue.target.value)
                        onChange(value)
                    }
                )
            )
        }
    }
}

private struct GroupHeader: Component {
    var key: AnyHashable? { title }

    var deps: Deps? {
        [title]
    }

    let title: String

    func render() -> Node {
        div(
            style: .init()
                .fontWeight("bold")
                .marginTop("4px")
                .color(Color.secondary)
        ) {
            title
        }
    }
}
