import React

internal struct InputRow: Component {
    internal init(
        text: String,
        value: String,
        placeholder: String = "",
        onChange: Function<Void, String>
    ) {
        self.text = text
        self.value = value
        self.placeholder = placeholder
        self.onChange = onChange
    }

    private var text: String
    private var value: String
    private var placeholder: String
    private var onChange: Function<Void, String>

    var key: AnyHashable? { text }

    var deps: Deps? {
        [text, value, placeholder, onChange]
    }

    func render() -> Node {
        label(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .alignItems("center")
                .gap("6px")
                .userSelect("none")
        ) {
            text
            input(
                attributes: .init()
                    .type("text")
                    .value(value)
                    .placeholder(placeholder),
                style: .init()
                    .font("inherit")
                    .padding("2px 6px")
                    .border("1px solid #ccc")
                    .borderRadius("3px"),
                listeners: .init().input(
                    EventListener { event in
                        let newValue = String.unsafeConstruct(from: event.jsValue.target.value)
                        onChange(newValue)
                    }
                )
            )
        }
    }
}
