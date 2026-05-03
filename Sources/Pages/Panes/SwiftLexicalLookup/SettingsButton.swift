import React

struct SettingsButton: Component {
    var deps: Deps? {
        [config, onConfigChange]
    }

    let config: LexicalLookupConfig
    let onConfigChange: Function<Void, LexicalLookupConfig>

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
                        onToggle: Function { toggle(\.hideEmptyCollections) }
                    )
                    CheckBoxRow(
                        text: "Hide Tokens",
                        checked: config.hideTokens,
                        onToggle: Function { toggle(\.hideTokens) }
                    )
                    CheckBoxRow(
                        text: "Hide Non-Scope",
                        checked: config.hideNonScope,
                        onToggle: Function { toggle(\.hideNonScope) }
                    )
                }
            }
        }
    }
}

private extension SettingsButton {
    func toggle(_ keyPath: WritableKeyPath<LexicalLookupConfig, Bool>) {
        var newConfig = config
        newConfig[keyPath: keyPath].toggle()
        onConfigChange(newConfig)
    }
}
