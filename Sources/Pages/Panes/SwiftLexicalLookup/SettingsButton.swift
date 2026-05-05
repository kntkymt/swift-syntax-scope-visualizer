import React
import SwiftReactPlus

struct SettingsButton: Component {
    var deps: Deps? {
        [_config]
    }

    @Binding var config: SwiftLexicalLookupPane.VisibleNodeConfig

    @State private var isPopoverOpen: Bool = false

    func render() -> Node {
        div(style: .init().position("relative")) {
            Button(onClick: Function { isPopoverOpen.toggle() }) {
                "Visible Settings"
            }

            if isPopoverOpen {
                Popover {
                    CheckBoxRow(
                        text: "Hide Non-Scope",
                        checked: config.hideNonScope,
                        onToggle: Function { config.hideNonScope.toggle() }
                    )
                    div(
                        style: .init()
                            .display("flex")
                            .flexDirection("column")
                            .gap("6px")
                            .paddingLeft("18px")
                    ) {
                        CheckBoxRow(
                            text: "Hide Empty Collections",
                            checked: config.hideEmptyCollections,
                            disabled: config.hideNonScope,
                            onToggle: Function { config.hideEmptyCollections.toggle() }
                        )
                        CheckBoxRow(
                            text: "Hide Tokens",
                            checked: config.hideTokens,
                            disabled: config.hideNonScope,
                            onToggle: Function { config.hideTokens.toggle() }
                        )
                    }
                }
            }
        }
    }
}
