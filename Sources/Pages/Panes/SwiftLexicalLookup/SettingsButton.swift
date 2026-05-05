import React
import SwiftReactPlus

struct SettingsButton: Component {
    var deps: Deps? {
        [_config]
    }

    @Binding var config: LexicalLookupConfig

    @State private var isPopoverOpen: Bool = false

    func render() -> Node {
        div(style: .init().position("relative")) {
            Button(onClick: Function { isPopoverOpen.toggle() }) {
                "Visible Settings"
            }

            if isPopoverOpen {
                Popover {
                    CheckBoxRow(
                        text: "Hide Empty Collections",
                        checked: config.hideEmptyCollections,
                        onToggle: Function { config.hideEmptyCollections.toggle() }
                    )
                    CheckBoxRow(
                        text: "Hide Tokens",
                        checked: config.hideTokens,
                        onToggle: Function { config.hideTokens.toggle() }
                    )
                    CheckBoxRow(
                        text: "Hide Non-Scope",
                        checked: config.hideNonScope,
                        onToggle: Function { config.hideNonScope.toggle() }
                    )
                }
            }
        }
    }
}
