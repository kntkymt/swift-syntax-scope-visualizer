import React
import SRTDOM

public struct SwiftCodeEditor: Component {
    public init(text: String, onInput: EventListener) {
        self.text = text
        self.onInput = onInput
    }

    public var text: String
    public var onInput: EventListener

    @Ref var gutterRef: JSHTMLElement?

    public var deps: Deps? {
        [text, onInput]
    }

    public func render() -> Node {
        let lineCount = text.count(where: \.isNewline) + 1
        let lineNumbers = (1...lineCount).map(String.init).joined(separator: "\n")

        // Keep the gutter's scroll position in sync with the textarea so that line numbers stay
        // aligned with their corresponding lines. The gutter is `overflow: hidden` and never
        // scrolls on its own, so we drive it programmatically by writing `scrollTop`.
        let onScroll = EventListener { (event) in
            guard let gutter = gutterRef else { return }
            gutter.jsValue.scrollTop = event.jsValue.target.scrollTop
        }

        // Insert a tab character on Tab instead of moving focus. `execCommand("insertText")` is
        // used because it preserves the native undo stack and dispatches an `input` event, which
        // lets the existing `onInput` listener pick up the change without extra wiring.
        let onKeyDown = EventListener { (event) in
            let key = String.unsafeConstruct(from: event.jsValue.key)
            guard key == "Tab" else { return }
            _ = event.jsValue.preventDefault()
            _ = JSWindow.global.document.jsValue.execCommand("insertText", false, "\t")
        }

        return div(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .flex("1 1 0")
                .minWidth("0")
                .height("100%")
                .borderRight("1px solid #ddd")
                .fontFamily("ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace")
                .fontSize("15px")
                .boxSizing("border-box")
        ) {
            div(
                ref: $gutterRef,
                style: .init()
                    .padding("8px 8px")
                    .textAlign("right")
                    .color("#888")
                    .backgroundColor("#f5f5f5")
                    .overflow("hidden")
                    .whiteSpace("pre")
                    .userSelect("none")
                    .borderRight("1px solid #ddd")
                    .minWidth("32px")
                    .boxSizing("border-box")
            ) {
                lineNumbers
            }

            textarea(
                attributes: .init()
                    .placeholder("input your swift code here")
                    .spellcheck("false")
                    .autocomplete("off")
                    .autocapitalize("off")
                    .wrap("off"),
                style: .init()
                    .flex("1 1 0")
                    .padding("8px")
                    .border("none")
                    .outline("none")
                    .resize("none")
                    .fontFamily("inherit")
                    .fontSize("inherit")
                    .lineHeight("inherit")
                    .whiteSpace("pre")
                    .tabSize("4")
                    .overflow("auto")
                    .boxSizing("border-box"),
                listeners: .init()
                    .input(onInput)
                    .scroll(onScroll)
                    .keydown(onKeyDown)
            )
        }
    }
}
