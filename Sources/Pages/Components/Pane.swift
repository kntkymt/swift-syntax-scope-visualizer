import React

internal struct Pane: Component {
    internal init(
        showRightBorder: Bool = true,
        scrollable: Bool = true,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.showRightBorder = showRightBorder
        self.scrollable = scrollable
        self.children = children()
    }

    private var showRightBorder: Bool
    private var scrollable: Bool
    private var children: [Node]

    func render() -> Node {
        div(
            style: .init()
                .flex("1 1 0")
                .minWidth("0")
                .height("100%")
                .overflow(scrollable ? "auto" : "visible")
                .padding(scrollable ? "8px" : "0")
                .borderRight(showRightBorder ? "1px solid #ddd" : "none")
                .boxSizing("border-box")
                .fontFamily("ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace")
        ) {
            children
        }
    }
}
