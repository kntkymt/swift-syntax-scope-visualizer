import JavaScriptKit
import React
import SRTDOM
import SwiftReactPlus

public struct ClickPointInfo: Hashable, Sendable {
    public var utf8Offset: Int
    public var clientPoint: SIMD2<Double>

    public init(utf8Offset: Int, clientPoint: SIMD2<Double>) {
        self.utf8Offset = utf8Offset
        self.clientPoint = clientPoint
    }
}

public struct SwiftCodeEditor: Component {
    public init(
        text: Binding<String>,
        highlightedRange: Range<Int>? = nil,
        isClickPointMode: Bool = false,
        onClickPoint: Function<Void, ClickPointInfo>? = nil
    ) {
        self._text = text
        self.highlightedRange = highlightedRange
        self.isClickPointMode = isClickPointMode
        self.onClickPoint = onClickPoint
    }

    @Binding public var text: String
    public var highlightedRange: Range<Int>?
    public var isClickPointMode: Bool
    public var onClickPoint: Function<Void, ClickPointInfo>?

    @Ref var gutterRef: JSHTMLElement?
    @Ref var overlayRef: JSHTMLElement?
    @Ref var textareaRef: JSHTMLElement?
    @Effect var highlightEffect

    public var deps: Deps? {
        [_text, highlightedRange, isClickPointMode, onClickPoint]
    }

    public func render() -> Node {
        let lineCount = text.count(where: \.isNewline) + 1
        let lineNumbers = (1...lineCount).map(String.init).joined(separator: "\n")

        let onInputEvent = EventListener { (event) in
            text = try! String.mustConstruct(from: event.jsValue.target.value)
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

        // In click-point mode, intercept the click on the textarea, translate the caret
        // position (UTF-16) to a UTF-8 byte offset, and report the on-screen anchor of that
        // caret (not the raw mouse coordinates) so callers can pin UI to the source position
        // itself — important when the user clicks past line ends.
        let onClick = EventListener { (event) in
            guard isClickPointMode, let onClickPoint else { return }
            let utf16Offset = Int(event.jsValue.target.selectionStart.number ?? 0)
            guard let utf8Offset = utf16OffsetToUtf8Offset(utf16Offset) else { return }
            let clientPoint = caretAnchorPoint(atUtf16Offset: utf16Offset)
            onClickPoint(ClickPointInfo(utf8Offset: utf8Offset, clientPoint: clientPoint))
        }

        // Highlight rectangles are positioned via the DOM Range API so widths are pixel-accurate
        // for any character (CJK, emoji ZWJ sequences, etc.). React doesn't manage these nodes;
        // the cleanup closure removes them before the next setup runs.
        $highlightEffect(deps: [highlightedRange, text]) {
            syncOverlayScroll()
            let installed = installHighlightRects()

            return {
                for element in installed {
                    _ = element.remove()
                }
            }
        }

        let baseTextareaAttributes: Attributes = .init()
            .placeholder("input your swift code here")
            .spellcheck("false")
            .autocomplete("off")
            .autocapitalize("off")
            .wrap("off")
        let textareaAttributes =
            isClickPointMode ? baseTextareaAttributes.readonly("") : baseTextareaAttributes

        let baseTextareaStyle: Style = .init()
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
            .boxSizing("border-box")
        let textareaStyle =
            isClickPointMode
            ? baseTextareaStyle.cursor("crosshair").caretColor("transparent")
            : baseTextareaStyle

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
                    attributes: textareaAttributes,
                    style: textareaStyle,
                    listeners: .init()
                        .input(onInputEvent)
                        .scroll(onScroll)
                        .keydown(onKeyDown)
                        .click(onClick)
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

    func utf16OffsetToUtf8Offset(_ utf16Offset: Int) -> Int? {
        let utf16 = text.utf16
        guard utf16Offset >= 0, utf16Offset <= utf16.count else { return nil }
        let utf16Index = utf16.index(utf16.startIndex, offsetBy: utf16Offset)
        guard let stringIndex = String.Index(utf16Index, within: text) else { return nil }
        return text.utf8.distance(from: text.utf8.startIndex, to: stringIndex)
    }

    // Resolve the viewport coordinates of the caret at `utf16Offset` by collapsing a DOM Range
    // on the overlay's transparent text node. Returns the bottom-left corner so anchored UI
    // sits just below the caret line.
    func caretAnchorPoint(atUtf16Offset utf16Offset: Int) -> SIMD2<Double> {
        guard let overlay = overlayRef else { return .zero }
        let textNode: JSValue = overlay.jsValue.firstChild
        guard Int(textNode.nodeType.number ?? 0) == 3 else { return .zero }

        let range = JSWindow.global.document.jsValue.createRange()
        _ = range.setStart(textNode, JSValue.number(Double(utf16Offset)))
        _ = range.setEnd(textNode, JSValue.number(Double(utf16Offset)))

        let bounds = range.getBoundingClientRect()
        let left = bounds.left.number ?? 0
        let bottom = bounds.bottom.number ?? 0
        return SIMD2(left, bottom)
    }

    func installHighlightRects() -> [JSValue] {
        guard let overlay = overlayRef, let range = highlightedRange else { return [] }

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
