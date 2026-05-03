import React

internal struct Button: Component {
    internal init(
        isActive: Bool = false,
        onClick: Function<Void>,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.isActive = isActive
        self.onClick = onClick
        self.children = children()
    }

    private var isActive: Bool
    private var onClick: Function<Void>
    private var children: [Node]

    var deps: Deps? {
        [isActive, onClick, children.deps]
    }

    func render() -> Node {
        button(
            style: .init()
                .padding("4px 10px")
                .border("1px solid #ccc")
                .borderRadius("4px")
                .backgroundColor(isActive ? Color.buttonActiveBackground : "#fff")
                .color("#000")
                .cursor("pointer")
                .font("inherit"),
            listeners: .init().click(EventListener { _ in onClick() })
        ) {
            children
        }
    }
}
