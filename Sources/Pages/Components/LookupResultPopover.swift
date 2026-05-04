import React
import SwiftSyntax

internal struct LookupResultPopover: Component {
    internal init(
        anchorPoint: SIMD2<Double>,
        sourceLocationDescription: String,
        lexicalLookupNames: [LookupResultName],
        syntaxScopeNames: [LookupResultName],
        onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>,
        onClose: Function<Void>
    ) {
        self.anchorPoint = anchorPoint
        self.sourceLocationDescription = sourceLocationDescription
        self.lexicalLookupNames = lexicalLookupNames
        self.syntaxScopeNames = syntaxScopeNames
        self.onHoverRangeChange = onHoverRangeChange
        self.onClose = onClose
    }

    private var anchorPoint: SIMD2<Double>
    private var sourceLocationDescription: String
    private var lexicalLookupNames: [LookupResultName]
    private var syntaxScopeNames: [LookupResultName]
    private var onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>
    private var onClose: Function<Void>

    var deps: Deps? {
        [
            anchorPoint, sourceLocationDescription,
            lexicalLookupNames, syntaxScopeNames,
            onHoverRangeChange, onClose,
        ]
    }

    func render() -> Node {
        Popover(
            anchor: .viewport(x: anchorPoint.x, y: anchorPoint.y),
            scrollable: true,
            onDismiss: onClose
        ) {
            div(style: .init().fontWeight("bold")) {
                "Lookup Result from \(sourceLocationDescription)"
            }
            LookupResultSection(
                title: "Swift Lexical Lookup",
                names: lexicalLookupNames,
                onHoverRangeChange: onHoverRangeChange
            )
            LookupResultSection(
                title: "Swift Syntax Scope",
                names: syntaxScopeNames,
                onHoverRangeChange: onHoverRangeChange
            )
        }
    }
}

private struct LookupResultSection: Component {
    var key: AnyHashable? { title }

    var deps: Deps? {
        [title, names, onHoverRangeChange]
    }

    let title: String
    let names: [LookupResultName]
    let onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>

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
                        onHoverRangeChange: onHoverRangeChange
                    )
                }
            }
        }
    }
}

private struct LookupResultRow: Component {
    var key: AnyHashable?

    var deps: Deps? {
        [key, name, onHoverRangeChange]
    }

    let name: LookupResultName
    let onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>

    @Callback var onHoverChange: Function<Void, Bool>

    init(
        key: AnyHashable? = nil,
        name: LookupResultName,
        onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>
    ) {
        self.key = key
        self.name = name
        self.onHoverRangeChange = onHoverRangeChange
    }

    func render() -> Node {
        $onHoverChange(deps: [name, onHoverRangeChange]) { (isHovered) in
            onHoverRangeChange(isHovered ? name.range : nil)
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
