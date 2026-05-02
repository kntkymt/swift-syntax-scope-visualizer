import React

internal struct HoverHighlight: Component {
    internal init(
        highlightColor: String = "rgba(100, 149, 237, 0.25)",
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.highlightColor = highlightColor
        self.children = children()
    }

    private var highlightColor: String
    private var children: [Node]

    @State private var isHovered: Bool = false

    func render() -> Node {
        // Highlight only the deepest hovered node and its descendants by stopping the mouse event
        // from bubbling. Descendants inherit the background through normal DOM stacking, while
        // ancestors receive a `mouseout` and clear their highlight as the cursor enters a child.
        let onMouseOver = EventListener { (event) in
            _ = event.jsValue.stopPropagation()
            self.isHovered = true
        }
        let onMouseOut = EventListener { (event) in
            _ = event.jsValue.stopPropagation()
            self.isHovered = false
        }

        return div(
            style: .init()
                .backgroundColor(isHovered ? highlightColor : "transparent"),
            listeners: .init()
                .mouseover(onMouseOver)
                .mouseout(onMouseOut)
        ) {
            children
        }
    }
}
