import React
import SwiftSyntax

internal struct LookupResultPopover: Component {
    internal init(
        result: LookupResultData,
        onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>,
        onUpdateHoveredSyntaxIds: Function<Void, Set<SyntaxIdentifier>>,
        onUpdateHoveredScopeIds: Function<Void, Set<ObjectIdentifier>>,
        onClose: Function<Void>
    ) {
        self.result = result
        self.onUpdateHighlightedSourceCodeRange = onUpdateHighlightedSourceCodeRange
        self.onUpdateHoveredSyntaxIds = onUpdateHoveredSyntaxIds
        self.onUpdateHoveredScopeIds = onUpdateHoveredScopeIds
        self.onClose = onClose
    }

    private var result: LookupResultData
    private var onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    private var onUpdateHoveredSyntaxIds: Function<Void, Set<SyntaxIdentifier>>
    private var onUpdateHoveredScopeIds: Function<Void, Set<ObjectIdentifier>>
    private var onClose: Function<Void>

    var deps: Deps? {
        [
            result,
            onUpdateHighlightedSourceCodeRange,
            onUpdateHoveredSyntaxIds,
            onUpdateHoveredScopeIds,
            onClose,
        ]
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
                results: result.lexicalLookupResults,
                onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange,
                onUpdateHoveredIds: onUpdateHoveredSyntaxIds
            )
            LookupResultSection(
                title: "Swift Syntax Scope",
                results: result.syntaxScopeResults,
                onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange,
                onUpdateHoveredIds: onUpdateHoveredScopeIds
            )
        }
    }
}

private struct LookupResultSection<NodeID: Hashable>: Component {
    var key: AnyHashable? { title }

    var deps: Deps? {
        [title, results, onUpdateHighlightedSourceCodeRange, onUpdateHoveredIds]
    }

    let title: String
    let results: [LookupResultDisplay<NodeID>]
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    let onUpdateHoveredIds: Function<Void, Set<NodeID>>

    func render() -> Node {
        div(
            style: .init()
                .display("flex")
                .flexDirection("column")
                .gap("4px")
        ) {
            div(style: .init().fontWeight("bold").color(Color.red)) { title }

            if results.isEmpty {
                div(style: .init().color(Color.secondary)) { "(no results)" }
            } else {
                Array(results.enumerated()).map { (index, displayResult) in
                    LookupResultRow(
                        key: index,
                        displayResult: displayResult,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange,
                        onUpdateHoveredIds: onUpdateHoveredIds
                    )
                }
            }
        }
    }
}

private struct LookupResultRow<NodeID: Hashable>: Component {
    var key: AnyHashable?

    var deps: Deps? {
        [key, displayResult, onUpdateHighlightedSourceCodeRange, onUpdateHoveredIds]
    }

    let displayResult: LookupResultDisplay<NodeID>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    let onUpdateHoveredIds: Function<Void, Set<NodeID>>

    @Callback var onHoverChange: Function<Void, Bool>

    init(
        key: AnyHashable? = nil,
        displayResult: LookupResultDisplay<NodeID>,
        onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>,
        onUpdateHoveredIds: Function<Void, Set<NodeID>>
    ) {
        self.key = key
        self.displayResult = displayResult
        self.onUpdateHighlightedSourceCodeRange = onUpdateHighlightedSourceCodeRange
        self.onUpdateHoveredIds = onUpdateHoveredIds
    }

    func render() -> Node {
        let headerRange = displayResult.headerRange
        let headerNodeId = displayResult.headerNodeId

        $onHoverChange(
            deps: [
                headerRange, headerNodeId,
                onUpdateHighlightedSourceCodeRange, onUpdateHoveredIds,
            ]
        ) { (isHovered) in
            onUpdateHighlightedSourceCodeRange(isHovered ? headerRange : nil)
            onUpdateHoveredIds(isHovered ? [headerNodeId] : [])
        }

        return div(
            style: .init()
                .display("flex")
                .flexDirection("column")
                .gap("2px")
        ) {
            HoverHighlight(onHoverChange: onHoverChange) {
                span { displayResult.headerLabel }
                span(
                    style: .init()
                        .marginLeft("8px")
                        .color(Color.secondary)
                ) { displayResult.headerRangeDescription }
            }

            if !displayResult.names.isEmpty {
                div(style: .init().marginLeft("16px")) {
                    Array(displayResult.names.enumerated()).map { (index, displayName) in
                        LookupNameRow(
                            key: index,
                            displayName: displayName,
                            onUpdateHighlightedSourceCodeRange:
                                onUpdateHighlightedSourceCodeRange,
                            onUpdateHoveredIds: onUpdateHoveredIds
                        )
                    }
                }
            }
        }
    }
}

private struct LookupNameRow<NodeID: Hashable>: Component {
    var key: AnyHashable?

    var deps: Deps? {
        [key, displayName, onUpdateHighlightedSourceCodeRange, onUpdateHoveredIds]
    }

    let displayName: LookupNameDisplay<NodeID>
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    let onUpdateHoveredIds: Function<Void, Set<NodeID>>

    @Callback var onHoverChange: Function<Void, Bool>

    init(
        key: AnyHashable? = nil,
        displayName: LookupNameDisplay<NodeID>,
        onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>,
        onUpdateHoveredIds: Function<Void, Set<NodeID>>
    ) {
        self.key = key
        self.displayName = displayName
        self.onUpdateHighlightedSourceCodeRange = onUpdateHighlightedSourceCodeRange
        self.onUpdateHoveredIds = onUpdateHoveredIds
    }

    func render() -> Node {
        switch displayName {
        case .leaf(
            let label,
            let nodeId,
            let range,
            let rangeDescription,
            let accessibleAfterDescription
        ):
            $onHoverChange(
                deps: [
                    range, nodeId, onUpdateHighlightedSourceCodeRange, onUpdateHoveredIds,
                ]
            ) { (isHovered) in
                onUpdateHighlightedSourceCodeRange(isHovered ? range : nil)
                onUpdateHoveredIds(isHovered ? [nodeId] : [])
            }

            return HoverHighlight(onHoverChange: onHoverChange) {
                span { label }
                span(
                    style: .init()
                        .marginLeft("8px")
                        .color(Color.secondary)
                ) { rangeDescription }
                if let accessibleAfterDescription {
                    span(
                        style: .init()
                            .marginLeft("8px")
                            .color(Color.secondary)
                    ) { "accessibleAfter: \(accessibleAfterDescription)" }
                }
            }

        case .equivalentNames(let nestedNames):
            return div(
                style: .init()
                    .display("flex")
                    .flexDirection("column")
                    .gap("2px")
            ) {
                span { "equivalentNames" }
                div(style: .init().marginLeft("16px")) {
                    Array(nestedNames.enumerated()).map { (index, nested) in
                        LookupNameRow(
                            key: index,
                            displayName: nested,
                            onUpdateHighlightedSourceCodeRange:
                                onUpdateHighlightedSourceCodeRange,
                            onUpdateHoveredIds: onUpdateHoveredIds
                        )
                    }
                }
            }
        }
    }
}
