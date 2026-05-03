import React
import SwiftCodeEditor

internal struct SwiftCodeEditorPane: Component {
    let text: String
    let highlightRange: Range<Int>?
    let onInput: Function<Void, String>

    var deps: Deps? {
        [text, highlightRange, onInput]
    }

    func render() -> Node {
        Pane(title: "Source Code", border: .right, scrollable: false) {
            SwiftCodeEditor(
                text: text,
                highlightRange: highlightRange,
                onInput: onInput
            )
        }
    }
}
