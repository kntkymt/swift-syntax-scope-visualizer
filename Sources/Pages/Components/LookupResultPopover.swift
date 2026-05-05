import React
import SwiftSyntax

internal struct LookupResultPopover: Component {
    internal init(
        result: LookupResultData,
        onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>,
        onClose: Function<Void>
    ) {
        self.result = result
        self.onUpdateHighlightedSourceCodeRange = onUpdateHighlightedSourceCodeRange
        self.onClose = onClose
    }

    private var result: LookupResultData
    private var onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    private var onClose: Function<Void>

    var deps: Deps? {
        [result, onUpdateHighlightedSourceCodeRange, onClose]
    }

    func render() -> Node {
        Popover(
            anchor: .viewport(x: result.anchorPoint.x, y: result.anchorPoint.y),
            scrollable: true,
            onDismiss: onClose
        ) {
            div(style: .init().fontWeight("bold")) {
                "Lookup Result from \(result.sourceLocationDescription)"
            }
            LookupResultSection(
                title: "Swift Lexical Lookup",
                names: result.lexicalLookupNames,
                onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
            )
            LookupResultSection(
                title: "Swift Syntax Scope",
                names: result.syntaxScopeNames,
                onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
            )
        }
    }
}

private struct LookupResultSection: Component {
    var key: AnyHashable? { title }

    var deps: Deps? {
        [title, names, onUpdateHighlightedSourceCodeRange]
    }

    let title: String
    let names: [LookupResultName]
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    func render() -> Node {
        div(
            style: .init()
                .display("flex")
                .flexDirection("column")
                .gap("4px")
        ) {
            div(style: .init().fontWeight("bold").color(Color.red)) { title }

            if names.isEmpty {
                div(style: .init().color(Color.secondary)) { "(no names)" }
            } else {
                Array(names.enumerated()).map { (index, name) in
                    LookupResultRow(
                        key: index,
                        name: name,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange
                    )
                }
            }
        }
    }
}

private struct LookupResultRow: Component {
    var key: AnyHashable?

    var deps: Deps? {
        [key, name, onUpdateHighlightedSourceCodeRange]
    }

    let name: LookupResultName
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>

    @Callback var onHoverChange: Function<Void, Bool>

    init(
        key: AnyHashable? = nil,
        name: LookupResultName,
        onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    ) {
        self.key = key
        self.name = name
        self.onUpdateHighlightedSourceCodeRange = onUpdateHighlightedSourceCodeRange
    }

    func render() -> Node {
        $onHoverChange(deps: [name, onUpdateHighlightedSourceCodeRange]) { (isHovered) in
            onUpdateHighlightedSourceCodeRange(isHovered ? name.range : nil)
        }

        return HoverHighlight(onHoverChange: onHoverChange) {
            span { name.label }
            span(
                style: .init()
                    .marginLeft("8px")
                    .color(Color.secondary)
            ) {
                "from: \(name.rangeDescription)"
            }
        }
    }
}
