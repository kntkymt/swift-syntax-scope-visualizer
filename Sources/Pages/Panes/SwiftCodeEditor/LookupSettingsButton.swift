import React
import SwiftReactPlus

struct LookupSettingsButton: Component {
    var deps: Deps? {
        [_config]
    }

    @Binding var config: LookupConfig

    @State private var isPopoverOpen: Bool = false

    func render() -> Node {
        div(style: .init().position("relative")) {
            Button(onClick: Function { isPopoverOpen.toggle() }) {
                "Lookup Configs"
            }

            if isPopoverOpen {
                Popover {
                    InputRow(
                        text: "Name",
                        value: config.name,
                        placeholder: "(any)",
                        onChange: Function { newName in
                            config.name = newName
                        }
                    )

                    GroupHeader(title: "Swift Lexical Lookup")
                    CheckBoxRow(
                        text: "Finish in sequential scope",
                        checked: config.swiftLexicalLookup.finishInSequentialScope,
                        onToggle: Function {
                            config.swiftLexicalLookup.finishInSequentialScope.toggle()
                        }
                    )

                    GroupHeader(title: "Swift Syntax Scope")
                    CheckBoxRow(
                        text: "Include outer results",
                        checked: config.swiftSyntaxScope.includeOuterResults,
                        onToggle: Function {
                            config.swiftSyntaxScope.includeOuterResults.toggle()
                        }
                    )
                }
            }
        }
    }
}
