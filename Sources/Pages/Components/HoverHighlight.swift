import React

internal struct HoverHighlight: Component {

    private var highlightColor: String
    private var onHoverChange: Function<Void, Bool>?
    private var children: [Node]

    @State private var isHovered: Bool = false

    internal init(
        highlightColor: String = "rgba(100, 149, 237, 0.25)",
        onHoverChange: Function<Void, Bool>? = nil,
        @ChildrenBuilder children: () -> [Node] = { [] }
    ) {
        self.highlightColor = highlightColor
        self.onHoverChange = onHoverChange
        self.children = children()
    }

    var deps: Deps? {
        [highlightColor, onHoverChange, children.deps]
    }

    func render() -> Node {
        // Highlight only the deepest hovered node and its descendants by stopping the mouse event
        // from bubbling. Descendants inherit the background through normal DOM stacking, while
        // ancestors receive a `mouseout` and clear their highlight as the cursor enters a child.
        let onMouseOver = EventListener { (event) in
            _ = event.jsValue.stopPropagation()
            self.isHovered = true
            onHoverChange?(true)
        }
        let onMouseOut = EventListener { (event) in
            _ = event.jsValue.stopPropagation()
            self.isHovered = false
            onHoverChange?(false)
        }

        return div(
            style: .init()
                .minWidth("max-content")
                .backgroundColor(isHovered ? highlightColor : "transparent"),
            listeners: .init()
                .mouseover(onMouseOver)
                .mouseout(onMouseOut)
        ) {
            children
        }
    }
}
