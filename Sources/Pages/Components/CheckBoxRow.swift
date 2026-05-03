import React

internal struct CheckBoxRow: Component {
    internal init(
        text: String,
        checked: Bool,
        onToggle: Function<Void>
    ) {
        self.text = text
        self.checked = checked
        self.onToggle = onToggle
    }

    private var text: String
    private var checked: Bool
    private var onToggle: Function<Void>

    var key: AnyHashable? { text }

    var deps: Deps? {
        [text, checked, onToggle]
    }

    func render() -> Node {
        let attributes: Attributes =
            checked
            ? Attributes(["type": "checkbox", "checked": ""])
            : Attributes(["type": "checkbox"])

        return label(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .alignItems("center")
                .gap("6px")
                .cursor("pointer")
                .userSelect("none")
        ) {
            input(
                attributes: attributes,
                listeners: .init().change(EventListener { _ in onToggle() })
            )
            text
        }
    }
}
