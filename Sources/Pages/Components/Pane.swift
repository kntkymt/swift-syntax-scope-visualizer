import React

internal struct Pane: Component {
    internal init(
        @ChildrenBuilder header: () -> [Node],
        showRightBorder: Bool = true,
        scrollable: Bool = true,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.header = header()
        self.showRightBorder = showRightBorder
        self.scrollable = scrollable
        self.children = children()
    }

    internal init(
        title: String,
        showRightBorder: Bool = true,
        scrollable: Bool = true,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.init(
            header: {
                h4(style: .init().margin("0")) { title }
            },
            showRightBorder: showRightBorder,
            scrollable: scrollable,
            children: children
        )
    }

    private var header: [Node]
    private var showRightBorder: Bool
    private var scrollable: Bool
    private var children: [Node]

    var deps: Deps? {
        [header.deps, showRightBorder, scrollable, children.deps]
    }

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
            div(
                style: .init()
                    .height("44px")
                    .padding("0 12px")
                    .flexShrink("0")
                    .boxSizing("border-box")
                    .borderBottom("1px solid #ddd")
                    .backgroundColor("#f5f5f5")
                    .display("flex")
                    .alignItems("center")
                    .justifyContent("space-between")
                    .gap("8px")
                    .fontFamily("system-ui, -apple-system, BlinkMacSystemFont, sans-serif")
            ) {
                header
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
