import React

internal struct Popover: Component {
    internal init(
        @ChildrenBuilder body: () -> [Node] = { [] }
    ) {
        self.body = body()
    }

    private var body: [Node]

    var deps: Deps? {
        [body.deps]
    }

    func render() -> Node {
        div(
            style: .init()
                .position("absolute")
                .top("calc(100% + 4px)")
                .right("0")
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
        ) {
            body
        }
    }
}
