import React

internal struct Popover: Component {
    internal enum Anchor: Hashable {
        // Pinned to the bottom-right of the nearest positioned ancestor.
        case parentBelowRight
        // Pinned to a viewport coordinate (e.g. a click point).
        case viewport(x: Double, y: Double)
    }

    internal init(
        anchor: Anchor = .parentBelowRight,
        scrollable: Bool = false,
        onDismiss: Function<Void>? = nil,
        @ChildrenBuilder body: () -> [Node] = { [] }
    ) {
        self.anchor = anchor
        self.scrollable = scrollable
        self.onDismiss = onDismiss
        self.body = body()
    }

    private var anchor: Anchor
    private var scrollable: Bool
    private var onDismiss: Function<Void>?
    private var body: [Node]

    var deps: Deps? {
        [anchor, scrollable, onDismiss, body.deps]
    }

    func render() -> Node {
        var boxStyle: Style = .init()
            .padding("8px 10px")
            .backgroundColor("#fff")
            .border("1px solid #ccc")
            .borderRadius("4px")
            .boxShadow("0 4px 12px rgba(0, 0, 0, 0.1)")
            .display("flex")
            .flexDirection("column")
            .gap("6px")
            .whiteSpace("nowrap")

        if scrollable {
            boxStyle =
                boxStyle
                .maxWidth("420px")
                .maxHeight("60vh")
                .overflow("auto")
        }

        // Stop click propagation inside the box so the dismiss overlay only fires for clicks
        // outside the popover content.
        let boxListeners: EventListeners =
            onDismiss != nil
            ? .init().click(
                EventListener { event in
                    _ = event.jsValue.stopPropagation()
                }
            )
            : .init()

        let popoverBox = div(style: boxStyle, listeners: boxListeners) { body }

        // Place the arrow on the wrapper (not inside the box) so a scrollable box's
        // `overflow: auto` doesn't clip it.
        let wrapperChildren: [Node] =
            anchor.hasArrow ? [Self.arrowNode(), popoverBox] : [popoverBox]
        let wrapper = div(style: anchor.wrapperStyle.zIndex("1")) { wrapperChildren }

        guard let onDismiss else {
            return wrapper
        }

        return div(
            style: .init()
                .position("fixed")
                .top("0")
                .left("0")
                .right("0")
                .bottom("0")
                .zIndex("10"),
            listeners: .init().click(EventListener { _ in onDismiss() })
        ) {
            wrapper
        }
    }
}

private extension Popover {
    static let arrowSize: Double = 16
    static let arrowSideOffset: Double = 12

    // A small box sized to the arrow that overlaps two border-triangles: the lower (outer)
    // shows the border color, the upper (inner) is offset down by 1px so only a 1px sliver
    // of the outer remains visible as the outline.
    static func arrowNode() -> Node {
        div(
            style: .init()
                .position("relative")
                .marginLeft("\(arrowSideOffset)px")
                .width("\(2 * arrowSize)px")
                .height("\(arrowSize)px")
        ) {
            arrowTriangle(topPx: 0, fill: "#ccc")
            arrowTriangle(topPx: 1, fill: "#fff")
        }
    }

    static func arrowTriangle(topPx: Double, fill: String) -> Node {
        div(
            style: .init()
                .position("absolute")
                .top("\(topPx)px")
                .left("0")
                .width("0")
                .height("0")
                .borderLeft("\(arrowSize)px solid transparent")
                .borderRight("\(arrowSize)px solid transparent")
                .borderBottom("\(arrowSize)px solid \(fill)")
        )
    }
}

private extension Popover.Anchor {
    var wrapperStyle: Style {
        switch self {
        case .parentBelowRight:
            return Style()
                .position("absolute")
                .top("calc(100% + 4px)")
                .right("0")
        case .viewport(let x, let y):
            // Place wrapper so the arrow tip aligns with (x, y): shift left by the arrow's
            // own offset within the wrapper plus its half-width.
            return Style()
                .position("fixed")
                .top("\(y)px")
                .left("\(x - Popover.arrowSideOffset - Popover.arrowSize)px")
        }
    }

    var hasArrow: Bool {
        switch self {
        case .parentBelowRight: return false
        case .viewport: return true
        }
    }
}
