import JavaScriptKit
import React
import SRTDOM

public struct SwiftCodeEditor: Component {
    public init(
        text: String,
        highlightRange: Range<Int>? = nil,
        onInput: Function<Void, String>
    ) {
        self.text = text
        self.highlightRange = highlightRange
        self.onInput = onInput
    }

    public var text: String
    public var highlightRange: Range<Int>?
    public var onInput: Function<Void, String>

    @Ref var gutterRef: JSHTMLElement?
    @Ref var overlayRef: JSHTMLElement?
    @Ref var textareaRef: JSHTMLElement?
    @Effect var highlightEffect

    public var deps: Deps? {
        [text, highlightRange, onInput]
    }

    public func render() -> Node {
        let lineCount = text.count(where: \.isNewline) + 1
        let lineNumbers = (1...lineCount).map(String.init).joined(separator: "\n")

        let onInputEvent = EventListener { (event) in
            let text = try! String.mustConstruct(from: event.jsValue.target.value)
            onInput(text)
        }

        // Keep the gutter and the highlight overlay's scroll position in sync with the textarea
        // so that line numbers and the highlight stay aligned with their corresponding lines.
        // Both elements are `overflow: hidden` and never scroll on their own, so we drive them
        // programmatically by writing `scrollTop` / `scrollLeft`.
        let onScroll = EventListener { (event) in
            if let gutter = gutterRef {
                gutter.jsValue.scrollTop = event.jsValue.target.scrollTop
            }

            if let overlay = overlayRef {
                overlay.jsValue.scrollTop = event.jsValue.target.scrollTop
                overlay.jsValue.scrollLeft = event.jsValue.target.scrollLeft
            }
        }

        // Insert a tab character on Tab instead of moving focus. `execCommand("insertText")` is
        // used because it preserves the native undo stack and dispatches an `input` event, which
        // lets the input listener pick up the change without extra wiring.
        let onKeyDown = EventListener { (event) in
            let key = String.unsafeConstruct(from: event.jsValue.key)
            guard key == "Tab" else { return }
            _ = event.jsValue.preventDefault()
            _ = JSWindow.global.document.jsValue.execCommand("insertText", false, "\t")
        }

        // Highlight rectangles are positioned via the DOM Range API so widths are pixel-accurate
        // for any character (CJK, emoji ZWJ sequences, etc.). React doesn't manage these nodes;
        // the cleanup closure removes them before the next setup runs.
        $highlightEffect(deps: [highlightRange, text]) {
            syncOverlayScroll()
            let installed = installHighlightRects()

            return {
                for element in installed {
                    _ = element.remove()
                }
            }
        }

        return div(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .height("100%")
                .fontSize("15px")
                .lineHeight("1.5")
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

            // Wrap the textarea in a relative container so the highlight overlay can be
            // absolutely positioned behind it. The overlay carries a transparent copy of the
            // text both to provide scrollable dimensions matching the textarea and to act as
            // the measurement target for the DOM Range API.
            div(
                style: .init()
                    .position("relative")
                    .flex("1 1 0")
                    .minWidth("0")
            ) {
                div(
                    ref: $overlayRef,
                    style: .init()
                        .position("absolute")
                        .top("0")
                        .left("0")
                        .right("0")
                        .bottom("0")
                        .padding("8px")
                        .fontFamily("inherit")
                        .fontSize("inherit")
                        .lineHeight("inherit")
                        .whiteSpace("pre")
                        .tabSize("4")
                        .color("transparent")
                        .pointerEvents("none")
                        .overflow("hidden")
                        .boxSizing("border-box")
                ) {
                    text
                }

                textarea(
                    ref: $textareaRef,
                    attributes: .init()
                        .placeholder("input your swift code here")
                        .spellcheck("false")
                        .autocomplete("off")
                        .autocapitalize("off")
                        .wrap("off"),
                    style: .init()
                        .width("100%")
                        .height("100%")
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
                        .backgroundColor("transparent")
                        .boxSizing("border-box"),
                    listeners: .init()
                        .input(onInputEvent)
                        .scroll(onScroll)
                        .keydown(onKeyDown)
                )
            }
        }
    }
}

private extension SwiftCodeEditor {
    static let editorPadding: Double = 8
    static let fontSizePx: Double = 15
    static let lineHeightMultiplier: Double = 1.5
    static let lineHeightPx: Double = fontSizePx * lineHeightMultiplier
    static let highlightColor = "rgba(81, 101, 255, 0.25)"
    // Over-extension for multi-line ranges; the overlay clips it via `overflow: hidden`.
    static let extendedWidthPx: Double = 9999

    struct LineSegment {
        var fileLineIndex: Int
        var startUTF16: Int
        var endUTF16: Int
        var isLineStart: Bool
    }

    func syncOverlayScroll() {
        guard let overlay = overlayRef, let textarea = textareaRef else { return }
        overlay.jsValue.scrollTop = textarea.jsValue.scrollTop
        overlay.jsValue.scrollLeft = textarea.jsValue.scrollLeft
    }

    func installHighlightRects() -> [JSValue] {
        guard let overlay = overlayRef, let range = highlightRange else { return [] }

        let utf8 = text.utf8
        guard
            range.lowerBound >= 0,
            range.upperBound <= utf8.count,
            range.lowerBound <= range.upperBound
        else { return [] }

        let textNode: JSValue = overlay.jsValue.firstChild
        // nodeType 3 = TEXT_NODE. Anything else means the overlay's first child isn't the
        // transparent text we expect, in which case Range setStart with a UTF-16 offset is
        // unsafe.
        guard Int(textNode.nodeType.number ?? 0) == 3 else { return [] }

        let segments = splitIntoLineSegments(byteRange: range)
        guard !segments.isEmpty else { return [] }

        let totalLines = text.utf8.lazy.filter { $0 == 0x0a }.count + 1
        let document = JSWindow.global.document.jsValue
        let overlayBounds = overlay.jsValue.getBoundingClientRect()
        let overlayLeftPx = overlayBounds.left.number ?? 0
        let scrollLeft = overlay.jsValue.scrollLeft.number ?? 0
        let padding = Self.editorPadding
        let lineHeight = Self.lineHeightPx

        var elements: [JSValue] = []

        for (index, segment) in segments.enumerated() {
            // Vertical: explicit line-box so adjacent rects touch and line-height gaps fill.
            var top = padding + Double(segment.fileLineIndex) * lineHeight
            var height = lineHeight

            // Horizontal: measure this line's sub-range with getBoundingClientRect, so each
            // line maps to exactly one rect regardless of browser quirks in getClientRects.
            let lineRange = document.createRange()
            _ = lineRange.setStart(textNode, JSValue.number(Double(segment.startUTF16)))
            _ = lineRange.setEnd(textNode, JSValue.number(Double(segment.endUTF16)))
            let lineBounds = lineRange.getBoundingClientRect()
            let measuredLeftPx = lineBounds.left.number ?? 0
            let measuredWidthPx = lineBounds.width.number ?? 0

            var left = (measuredLeftPx - overlayLeftPx) + scrollLeft
            var width = measuredWidthPx

            let isFirst = index == 0
            let isLast = index == segments.count - 1
            let isSingle = isFirst && isLast

            if isSingle {
                if segment.isLineStart {
                    width += left
                    left = 0
                }
            } else if isFirst {
                if segment.isLineStart { left = 0 }
                width = Self.extendedWidthPx
            } else if isLast {
                width += left
                left = 0
            } else {
                left = 0
                width = Self.extendedWidthPx
            }

            // Vertical padding extension when the range touches the file's first / last line.
            if isFirst && segment.fileLineIndex == 0 {
                height += top
                top = 0
            }
            if isLast && segment.fileLineIndex == totalLines - 1 {
                height += padding
            }

            let div = document.createElement("div")
            let style = """
                position:absolute;\
                top:\(top)px;left:\(left)px;\
                width:\(width)px;height:\(height)px;\
                background-color:\(Self.highlightColor);\
                pointer-events:none;
                """
            _ = div.setAttribute("style", style)
            _ = overlay.jsValue.appendChild(div)
            elements.append(div)
        }

        return elements
    }

    // Split the byte range at `\n` boundaries so each visual line of the highlight gets
    // exactly one entry. UTF-16 offsets are pre-computed for use with the DOM Range API.
    func splitIntoLineSegments(byteRange: Range<Int>) -> [LineSegment] {
        let utf8 = text.utf8
        let utf16 = text.utf16

        func utf16Distance(toByteOffset byteOffset: Int) -> Int? {
            let utf8Index = utf8.index(utf8.startIndex, offsetBy: byteOffset)
            guard let stringIndex = String.Index(utf8Index, within: text) else { return nil }
            return utf16.distance(from: utf16.startIndex, to: stringIndex)
        }

        var fileLineIndex: Int = {
            var count = 0
            var idx = utf8.startIndex
            let stop = utf8.index(utf8.startIndex, offsetBy: byteRange.lowerBound)
            while idx < stop {
                if utf8[idx] == 0x0a { count += 1 }
                idx = utf8.index(after: idx)
            }
            return count
        }()

        var isCurrentLineStart: Bool = {
            guard byteRange.lowerBound > 0 else { return true }
            let prev = utf8.index(utf8.startIndex, offsetBy: byteRange.lowerBound - 1)
            return utf8[prev] == 0x0a
        }()

        var segments: [LineSegment] = []
        var lineStartByte = byteRange.lowerBound
        var byteIdx = byteRange.lowerBound

        while byteIdx < byteRange.upperBound {
            let bytePos = utf8.index(utf8.startIndex, offsetBy: byteIdx)
            if utf8[bytePos] == 0x0a {
                if let startU16 = utf16Distance(toByteOffset: lineStartByte),
                    let endU16 = utf16Distance(toByteOffset: byteIdx)
                {
                    segments.append(
                        LineSegment(
                            fileLineIndex: fileLineIndex,
                            startUTF16: startU16,
                            endUTF16: endU16,
                            isLineStart: isCurrentLineStart
                        )
                    )
                }

                fileLineIndex += 1
                lineStartByte = byteIdx + 1
                isCurrentLineStart = true
            }
            byteIdx += 1
        }

        if let startU16 = utf16Distance(toByteOffset: lineStartByte),
            let endU16 = utf16Distance(toByteOffset: byteRange.upperBound)
        {
            segments.append(
                LineSegment(
                    fileLineIndex: fileLineIndex,
                    startUTF16: startU16,
                    endUTF16: endU16,
                    isLineStart: isCurrentLineStart
                )
            )
        }

        return segments
    }
}
