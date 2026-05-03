import React

internal struct Pane: Component {
    struct BorderPosition: OptionSet, Hashable {
        var rawValue: Int

        static let left = BorderPosition(rawValue: 1 << 0)
        static let right = BorderPosition(rawValue: 1 << 1)
    }

    internal init(
        @ChildrenBuilder header: () -> [Node],
        border: BorderPosition,
        scrollable: Bool = true,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.header = header()
        self.border = border
        self.scrollable = scrollable
        self.children = children()
    }

    internal init(
        title: String,
        border: BorderPosition,
        scrollable: Bool = true,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.init(
            header: {
                h4(style: .init().margin("0")) { title }
            },
            border: border,
            scrollable: scrollable,
            children: children
        )
    }

    private var header: [Node]
    private var border: BorderPosition
    private var scrollable: Bool
    private var children: [Node]

    var deps: Deps? {
        [header.deps, border, scrollable, children.deps]
    }

    func render() -> Node {
        div(
            style: .init()
                .flex("1 1 0")
                .minWidth("0")
                .height("100%")
                .display("flex")
                .flexDirection("column")
                .borderLeft(border.contains(.left) ? "1px solid #ddd" : "none")
                .borderRight(border.contains(.right) ? "1px solid #ddd" : "none")
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
