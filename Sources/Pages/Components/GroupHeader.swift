import React

internal struct GroupHeader: Component {
    internal init(title: String) {
        self.title = title
    }

    private var title: String

    var key: AnyHashable? { title }

    var deps: Deps? {
        [title]
    }

    func render() -> Node {
        div(
            style: .init()
                .fontWeight("bold")
                .marginTop("4px")
                .color(Color.secondary)
        ) {
            title
        }
    }
}
