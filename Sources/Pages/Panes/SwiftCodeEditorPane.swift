import React
import SwiftCodeEditor

internal struct SwiftCodeEditorPane: Component {
    let text: String
    let onInput: Function<Void, String>

    var deps: Deps? {
        [text, onInput]
    }

    func render() -> Node {
        Pane(title: "Source Code", border: .right, scrollable: false) {
            SwiftCodeEditor(text: text, onInput: onInput)
        }
    }
}
