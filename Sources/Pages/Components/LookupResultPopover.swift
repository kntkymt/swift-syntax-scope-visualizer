import React

internal struct LookupResultPopover: Component {
    internal init(
        clientX: Double,
        clientY: Double,
        lexicalLookupNames: [LookupResultName],
        syntaxScopeNames: [LookupResultName],
        onClose: Function<Void>
    ) {
        self.clientX = clientX
        self.clientY = clientY
        self.lexicalLookupNames = lexicalLookupNames
        self.syntaxScopeNames = syntaxScopeNames
        self.onClose = onClose
    }

    private var clientX: Double
    private var clientY: Double
    private var lexicalLookupNames: [LookupResultName]
    private var syntaxScopeNames: [LookupResultName]
    private var onClose: Function<Void>

    var deps: Deps? {
        [clientX, clientY, lexicalLookupNames, syntaxScopeNames, onClose]
    }

    func render() -> Node {
        Popover(
            anchor: .viewport(x: clientX, y: clientY),
            scrollable: true,
            onDismiss: onClose
        ) {
            LookupResultSection(
                title: "Swift Lexical Lookup",
                names: lexicalLookupNames
            )
            LookupResultSection(
                title: "Swift Syntax Scope",
                names: syntaxScopeNames
            )
        }
    }
}

private struct LookupResultSection: Component {
    var key: AnyHashable? { title }

    var deps: Deps? {
        [title, names]
    }

    let title: String
    let names: [LookupResultName]

    func render() -> Node {
        div(
            style: .init()
                .display("flex")
                .flexDirection("column")
                .gap("4px")
        ) {
            div(style: .init().fontWeight("bold").color(Color.red)) { title }

            if names.isEmpty {
                div(style: .init().color(Color.secondary)) { "(no names)" }
            } else {
                Array(names.enumerated()).map { (index, name) in
                    div(key: index) {
                        span { name.label }
                        span(
                            style: .init()
                                .marginLeft("8px")
                                .color(Color.secondary)
                        ) {
                            name.range
                        }
                    }
                }
            }
        }
    }
}
