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
            LexicalLookupSection(
                title: "Swift Lexical Lookup",
                results: result.lexicalLookupResults,
                onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange,
                onUpdateHoveredSyntaxIds: onUpdateHoveredSyntaxIds
            )
            SyntaxScopeNamesSection(
                title: "Swift Syntax Scope",
                names: result.syntaxScopeNames,
                onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange,
                onUpdateHoveredScopeIds: onUpdateHoveredScopeIds
            )
        }
    }
}

private struct LexicalLookupSection: Component {
    var key: AnyHashable? { title }

    var deps: Deps? {
        [title, results, onUpdateHighlightedSourceCodeRange, onUpdateHoveredSyntaxIds]
    }

    let title: String
    let results: [LexicalLookupResultDisplay]
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    let onUpdateHoveredSyntaxIds: Function<Void, Set<SyntaxIdentifier>>

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
                    LexicalLookupResultRow(
                        key: index,
                        displayResult: displayResult,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange,
                        onUpdateHoveredSyntaxIds: onUpdateHoveredSyntaxIds
                    )
                }
            }
        }
    }
}

private struct LexicalLookupResultRow: Component {
    var key: AnyHashable?

    var deps: Deps? {
        [key, displayResult, onUpdateHighlightedSourceCodeRange, onUpdateHoveredSyntaxIds]
    }

    let displayResult: LexicalLookupResultDisplay
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    let onUpdateHoveredSyntaxIds: Function<Void, Set<SyntaxIdentifier>>

    @Callback var onHoverChange: Function<Void, Bool>

    init(
        key: AnyHashable? = nil,
        displayResult: LexicalLookupResultDisplay,
        onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>,
        onUpdateHoveredSyntaxIds: Function<Void, Set<SyntaxIdentifier>>
    ) {
        self.key = key
        self.displayResult = displayResult
        self.onUpdateHighlightedSourceCodeRange = onUpdateHighlightedSourceCodeRange
        self.onUpdateHoveredSyntaxIds = onUpdateHoveredSyntaxIds
    }

    func render() -> Node {
        let headerRange = displayResult.headerRange
        let headerSyntaxId = displayResult.headerSyntaxId

        $onHoverChange(
            deps: [
                headerRange, headerSyntaxId, onUpdateHighlightedSourceCodeRange,
                onUpdateHoveredSyntaxIds,
            ]
        ) { (isHovered) in
            onUpdateHighlightedSourceCodeRange(isHovered ? headerRange : nil)
            onUpdateHoveredSyntaxIds(isHovered ? [headerSyntaxId] : [])
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
                        LexicalLookupNameRow(
                            key: index,
                            displayName: displayName,
                            onUpdateHighlightedSourceCodeRange:
                                onUpdateHighlightedSourceCodeRange,
                            onUpdateHoveredSyntaxIds: onUpdateHoveredSyntaxIds
                        )
                    }
                }
            }
        }
    }
}

private struct LexicalLookupNameRow: Component {
    var key: AnyHashable?

    var deps: Deps? {
        [key, displayName, onUpdateHighlightedSourceCodeRange, onUpdateHoveredSyntaxIds]
    }

    let displayName: LexicalLookupNameDisplay
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    let onUpdateHoveredSyntaxIds: Function<Void, Set<SyntaxIdentifier>>

    @Callback var onHoverChange: Function<Void, Bool>

    init(
        key: AnyHashable? = nil,
        displayName: LexicalLookupNameDisplay,
        onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>,
        onUpdateHoveredSyntaxIds: Function<Void, Set<SyntaxIdentifier>>
    ) {
        self.key = key
        self.displayName = displayName
        self.onUpdateHighlightedSourceCodeRange = onUpdateHighlightedSourceCodeRange
        self.onUpdateHoveredSyntaxIds = onUpdateHoveredSyntaxIds
    }

    func render() -> Node {
        switch displayName {
        case .leaf(
            let label,
            let syntaxId,
            let range,
            let rangeDescription,
            let accessibleAfterDescription
        ):
            $onHoverChange(
                deps: [
                    range, syntaxId, onUpdateHighlightedSourceCodeRange, onUpdateHoveredSyntaxIds,
                ]
            ) { (isHovered) in
                onUpdateHighlightedSourceCodeRange(isHovered ? range : nil)
                onUpdateHoveredSyntaxIds(isHovered ? [syntaxId] : [])
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
                        LexicalLookupNameRow(
                            key: index,
                            displayName: nested,
                            onUpdateHighlightedSourceCodeRange:
                                onUpdateHighlightedSourceCodeRange,
                            onUpdateHoveredSyntaxIds: onUpdateHoveredSyntaxIds
                        )
                    }
                }
            }
        }
    }
}

private struct SyntaxScopeNamesSection: Component {
    var key: AnyHashable? { title }

    var deps: Deps? {
        [title, names, onUpdateHighlightedSourceCodeRange, onUpdateHoveredScopeIds]
    }

    let title: String
    let names: [SyntaxScopeNameDisplay]
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    let onUpdateHoveredScopeIds: Function<Void, Set<ObjectIdentifier>>

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
                    SyntaxScopeNameRow(
                        key: index,
                        displayName: name,
                        onUpdateHighlightedSourceCodeRange: onUpdateHighlightedSourceCodeRange,
                        onUpdateHoveredScopeIds: onUpdateHoveredScopeIds
                    )
                }
            }
        }
    }
}

private struct SyntaxScopeNameRow: Component {
    var key: AnyHashable?

    var deps: Deps? {
        [key, displayName, onUpdateHighlightedSourceCodeRange, onUpdateHoveredScopeIds]
    }

    let displayName: SyntaxScopeNameDisplay
    let onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>
    let onUpdateHoveredScopeIds: Function<Void, Set<ObjectIdentifier>>

    @Callback var onHoverChange: Function<Void, Bool>

    init(
        key: AnyHashable? = nil,
        displayName: SyntaxScopeNameDisplay,
        onUpdateHighlightedSourceCodeRange: Function<Void, Range<AbsolutePosition>?>,
        onUpdateHoveredScopeIds: Function<Void, Set<ObjectIdentifier>>
    ) {
        self.key = key
        self.displayName = displayName
        self.onUpdateHighlightedSourceCodeRange = onUpdateHighlightedSourceCodeRange
        self.onUpdateHoveredScopeIds = onUpdateHoveredScopeIds
    }

    func render() -> Node {
        let range = displayName.range
        let scopeId = displayName.scopeId
        let scopeIds: Set<ObjectIdentifier> = scopeId.map { [$0] } ?? []

        $onHoverChange(
            deps: [range, scopeIds, onUpdateHighlightedSourceCodeRange, onUpdateHoveredScopeIds]
        ) { (isHovered) in
            onUpdateHighlightedSourceCodeRange(isHovered ? range : nil)
            onUpdateHoveredScopeIds(isHovered ? scopeIds : [])
        }

        return HoverHighlight(onHoverChange: onHoverChange) {
            span { displayName.label }
            span(
                style: .init()
                    .marginLeft("8px")
                    .color(Color.secondary)
            ) {
                "from: \(displayName.rangeDescription)"
            }
        }
    }
}
