import React

internal struct CheckBoxRow: Component {
    internal init(
        text: String,
        checked: Bool,
        disabled: Bool = false,
        onToggle: Function<Void>
    ) {
        self.text = text
        self.checked = checked
        self.disabled = disabled
        self.onToggle = onToggle
    }

    private var text: String
    private var checked: Bool
    private var disabled: Bool
    private var onToggle: Function<Void>

    var key: AnyHashable? { text }

    var deps: Deps? {
        [text, checked, disabled, onToggle]
    }

    func render() -> Node {
        var attributes: Attributes = .init().type("checkbox")
        if checked {
            attributes = attributes.checked("")
        }
        if disabled {
            attributes = attributes.disabled("")
        }

        return label(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .alignItems("center")
                .gap("6px")
                .cursor(disabled ? "not-allowed" : "pointer")
                .userSelect("none")
                .opacity(disabled ? "0.5" : "1")
        ) {
            input(
                attributes: attributes,
                listeners: .init().change(EventListener { _ in onToggle() })
            )
            text
        }
    }
}
