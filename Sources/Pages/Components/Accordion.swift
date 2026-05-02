import React

internal struct Accordion: Component {
    internal init(
        initiallyExpanded: Bool = true,
        @ChildrenBuilder header: () -> [Node],
        @ChildrenBuilder body: () -> [Node] = { [] }
    ) {
        self.header = header()
        self.body = body()
        self._isExpanded = State(wrappedValue: initiallyExpanded)
    }

    private var header: [Node]
    private var body: [Node]

    var deps: Deps? {
        [header.deps, body.deps]
    }

    @State private var isExpanded: Bool

    func render() -> Node {
        let isExpandable = !body.isEmpty

        let onToggle = EventListener { (_) in
            guard isExpandable else { return }
            self.isExpanded.toggle()
        }

        return div {
            div(
                style: .init()
                    .display("flex")
                    .flexDirection("row")
                    .alignItems("baseline")
                    .cursor(isExpandable ? "pointer" : "default")
                    .userSelect("none"),
                listeners: .init().click(onToggle)
            ) {
                span(
                    style: .init()
                        .display("inline-block")
                        .width("12px")
                        .color("#888")
                ) {
                    isExpandable ? (isExpanded ? "▾" : "▸") : ""
                }

                header
            }

            if isExpandable && isExpanded {
                div(
                    style: .init()
                        .paddingLeft("12px")
                        .marginLeft("4px")
                        .borderLeft("1px solid #eee")
                ) {
                    body
                }
            }
        }
    }
}
