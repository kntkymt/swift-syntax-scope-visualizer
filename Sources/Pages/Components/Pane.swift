import React

internal struct Pane: Component {
    internal init(
        title: String,
        showRightBorder: Bool = true,
        scrollable: Bool = true,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.title = title
        self.showRightBorder = showRightBorder
        self.scrollable = scrollable
        self.children = children()
    }

    private var title: String
    private var showRightBorder: Bool
    private var scrollable: Bool
    private var children: [Node]

    func render() -> Node {
        div(
            style: .init()
                .flex("1 1 0")
                .minWidth("0")
                .height("100%")
                .display("flex")
                .flexDirection("column")
                .borderRight(showRightBorder ? "1px solid #ddd" : "none")
                .boxSizing("border-box")
                .fontFamily("ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace")
        ) {
            h4(
                style: .init()
                    .margin("0")
                    .padding("8px 12px")
                    .flexShrink("0")
                    .borderBottom("1px solid #ddd")
                    .backgroundColor("#f5f5f5")
                    .fontFamily("system-ui, -apple-system, BlinkMacSystemFont, sans-serif")
            ) {
                title
            }

            div(
                style: .init()
                    .flex("1 1 0")
                    .minHeight("0")
                    .overflow(scrollable ? "auto" : "visible")
                    .padding(scrollable ? "8px" : "0")
                    .boxSizing("border-box")
            ) {
                children
            }
        }
    }
}
