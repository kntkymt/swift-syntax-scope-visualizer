import React

struct LookupSettingsButton: Component {
    var deps: Deps? {
        [config, onConfigChange]
    }

    let config: LookupConfig
    let onConfigChange: Function<Void, LookupConfig>

    @State private var isPopoverOpen: Bool = false

    func render() -> Node {
        div(style: .init().position("relative")) {
            Button(onClick: Function { isPopoverOpen.toggle() }) {
                "Lookup Settings"
            }

            if isPopoverOpen {
                Popover {
                    InputRow(
                        text: "Name",
                        value: config.name,
                        placeholder: "(any)",
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
