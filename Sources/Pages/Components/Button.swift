import React

internal struct Button: Component {
    internal init(
        isActive: Bool = false,
        onClick: Function<Void>,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.isActive = isActive
        self.action = .click(onClick)
        self.children = children()
    }

    internal init(
        href: String,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.isActive = false
        self.action = .link(href: href)
        self.children = children()
    }

    private enum Action: Hashable {
        case click(Function<Void>)
        case link(href: String)
    }

    private var isActive: Bool
    private var action: Action
    private var children: [Node]

    var deps: Deps? {
        [isActive, action, children.deps]
    }

    func render() -> Node {
        let style: Style = .init()
            .padding("4px 10px")
            .border("1px solid #ccc")
            .borderRadius("8px")
            .backgroundColor(isActive ? Color.buttonActiveBackground : "#fff")
            .color("#000")
            .cursor("pointer")
            .font("inherit")

        switch action {
        case .click(let onClick):
            return button(
                style: style,
                listeners: .init().click(EventListener { _ in onClick() })
            ) {
                children
            }
        case .link(let href):
            return a(
                attributes: .init()
                    .href(href)
                    .target("_blank")
                    .rel("noopener noreferrer"),
                style: style.textDecoration("none")
            ) {
                children
            }
        }
    }
}
