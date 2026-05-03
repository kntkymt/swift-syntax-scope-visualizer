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
        var boxStyle: Style = anchor.positionStyle
            .padding("8px 10px")
            .backgroundColor("#fff")
            .border("1px solid #ccc")
            .borderRadius("4px")
            .boxShadow("0 4px 12px rgba(0, 0, 0, 0.1)")
            .display("flex")
            .flexDirection("column")
            .gap("6px")
            .whiteSpace("nowrap")
            .zIndex("1")

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

        guard let onDismiss else {
            return popoverBox
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
            popoverBox
        }
    }
}

private extension Popover.Anchor {
    var positionStyle: Style {
        switch self {
        case .parentBelowRight:
            return Style()
                .position("absolute")
                .top("calc(100% + 4px)")
                .right("0")
        case .viewport(let x, let y):
            return Style()
                .position("fixed")
                .top("\(y)px")
                .left("\(x)px")
        }
    }
}
