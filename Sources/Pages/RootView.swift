import React
import SRTJavaScriptKitEx
import SwiftCodeEditor
@_spi(Experimental) import SwiftLexicalLookup
import SwiftParser
import SwiftSyntax
import SwiftSyntaxScope

public struct RootView: Component {

    @State var text: String = ""
    @State var parsed: ParsedSource = ParsedSource(from: "")
    @State var highlightedRange: Range<AbsolutePosition>? = nil
    @State var lookupConfig: LookupConfig = .default
    @State var lookupResult: LookupResultData? = nil
    @Effect var parseEffect
    @Callback var onHoverRangeChange: Function<Void, Range<AbsolutePosition>?>
    @Callback var onLookup: Function<Void, ClickPointInfo>
    @Callback var onLookupConfigChange: Function<Void, LookupConfig>
    @Callback var onLookupClose: Function<Void>

    public init() {}

    public func render() -> Node {
        let onTextChange = Function<Void, String> { (text) in
            self.text = text
        }

        // Debounce text -> SourceFileSyntax. Cleanup captures `timer` so that
        // dropping the closure releases the JSTimer, triggering clearTimeout
        // via its deinit.
        $parseEffect(deps: [text]) {
            let pendingText = text
            let timer = JSTimer(millisecondsDelay: 500) {
                parsed = ParsedSource(from: pendingText)
            }

            return {
                _ = timer
            }
        }

        $onHoverRangeChange(deps: []) { (range) in
            self.highlightedRange = range
        }

        $onLookup(deps: [parsed.syntax.id, lookupConfig]) { (info) in
            self.lookupResult = parsed.scope.makeLookupResult(
                info: info,
                config: lookupConfig
            )
        }

        $onLookupConfigChange(deps: []) { (newConfig) in
            self.lookupConfig = newConfig
        }

        $onLookupClose(deps: []) {
            self.lookupResult = nil
        }

        return div(
            style: .init()
                .display("flex")
                .flexDirection("row")
                .height("100vh")
                .overflow("hidden")
        ) {
            Pane(
                title: "Swift Syntax Scope Visualizer",
                border: [],
                scrollable: false
            ) {
                div(
                    style: .init()
                        .display("flex")
                        .flexDirection("row")
                        .height("100%")
                ) {
                    SwiftCodeEditorPane(
                        text: text,
                        highlightRange: highlightedRange.map {
                            $0.lowerBound.utf8Offset..<$0.upperBound.utf8Offset
                        },
                        lookupConfig: lookupConfig,
                        onInput: onTextChange,
                        onLookup: onLookup,
                        onLookupConfigChange: onLookupConfigChange
                    )
                    SwiftLexicalLookupPane(
                        syntax: parsed.syntax,
                        highlightedSyntaxIds: lookupResult?.lexicalLookupOriginSyntaxIds ?? [],
                        onHoverRangeChange: onHoverRangeChange
                    )
                    SwiftSyntaxScopePane(
                        scope: parsed.scope,
                        highlightedScopeIds: lookupResult?.syntaxScopeOriginScopeIds ?? [],
                        onHoverRangeChange: onHoverRangeChange
                    )
                }
            }

            if let lookupResult {
                LookupResultPopover(
                    anchorPoint: SIMD2(lookupResult.clientX, lookupResult.clientY),
                    sourceLocationDescription: lookupResult.sourceLocationDescription,
                    lexicalLookupNames: lookupResult.lexicalLookupNames,
                    syntaxScopeNames: lookupResult.syntaxScopeNames,
                    onHoverRangeChange: onHoverRangeChange,
                    onClose: onLookupClose
                )
            }
        }
    }
}

struct ParsedSource: Equatable {
    init(from text: String) {
        self.text = text
        let syntax = Parser.parse(source: text)
        self.syntax = syntax
        let scope = SourceFileScope(syntax: syntax)
        scope.buildFullyExpandedTree()
        self.scope = scope
    }

    let text: String
    let syntax: SourceFileSyntax
    let scope: SourceFileScope

    static func == (lhs: ParsedSource, rhs: ParsedSource) -> Bool {
        lhs.text == rhs.text
    }
}

internal struct LookupResultName: Hashable {
    var label: String
    var range: Range<AbsolutePosition>
    var rangeDescription: String
}

internal struct LookupResultData: Equatable {
    var clientX: Double
    var clientY: Double
    var sourceLocationDescription: String
    var lexicalLookupNames: [LookupResultName]
    var syntaxScopeNames: [LookupResultName]
    var lexicalLookupOriginSyntaxIds: Set<SyntaxIdentifier>
    var syntaxScopeOriginScopeIds: Set<ObjectIdentifier>
}

private extension SourceFileScope {
    func makeLookupResult(
        info: ClickPointInfo,
        config: LookupConfig
    ) -> LookupResultData {
        let position = AbsolutePosition(utf8Offset: info.utf8Offset)
        let identifier = config.name.asLookupIdentifier
        let converter = SourceLocationConverter(fileName: "", tree: syntax.root)
        let location = converter.location(for: position)
        let sourceLocationDescription = "\(location.line):\(location.column)"
        let lexicalConfig = SwiftLexicalLookup.LookupConfig(
            finishInSequentialScope: config.swiftLexicalLookup.finishInSequentialScope
        )
        let options: LookupOptions =
            config.swiftSyntaxScope.includeOuterResults ? .includeOuterResults : []

        let originToken = syntax.token(at: position)

        let lexicalLookupNames =
            (originToken?.lookup(identifier, with: lexicalConfig) ?? [])
            .flatMap { (result: LookupResult) -> [LookupResultName] in
                switch result {
                case .fromScope(_, let names):
                    return names.flatMap(\.flattened).map { name in
                        LookupResultName(
                            label: name.displayDescription,
                            range: name.syntax.trimmedRange,
                            rangeDescription: name.syntax.sourceRange(converter: converter)
                                .description
                        )
                    }
                case .lookForMembers(let syntax):
                    return [
                        LookupResultName(
                            label: "lookForMembers:\(syntax.syntaxNodeType)",
                            range: syntax.trimmedRange,
                            rangeDescription: syntax.sourceRange(converter: converter).description
                        )
                    ]
                case .lookForGenericParameters(let extensionDecl):
                    return [
                        LookupResultName(
                            label: "lookForGenericParameters:\(extensionDecl.syntaxNodeType)",
                            range: extensionDecl.trimmedRange,
                            rangeDescription: extensionDecl.sourceRange(converter: converter)
                                .description
                        )
                    ]
                case .lookForImplicitClosureParameters(let closureExpr):
                    return [
                        LookupResultName(
                            label: "lookForImplicitClosureParameters:\(closureExpr.syntaxNodeType)",
                            range: closureExpr.trimmedRange,
                            rangeDescription: closureExpr.sourceRange(converter: converter)
                                .description
                        )
                    ]
                }
            }

        let syntaxScopeNames = self.lexicalLookup(
            position: position,
            name: identifier,
            options: options
        )
        .map { name in
            LookupResultName(
                label: "\(name.kind):\(name.text)",
                range: name.syntax.trimmedRange,
                rangeDescription: name.syntax.sourceRange(converter: converter).description
            )
        }

        let lexicalLookupOriginSyntaxIds: Set<SyntaxIdentifier> = {
            guard let token = originToken else { return [] }
            var ids: Set<SyntaxIdentifier> = []
            var current: ScopeSyntax? = token.nearestEnclosingScope
            while let scope = current {
                ids.insert(scope.id)
                current = scope.parentScope
            }
            return ids
        }()

        let syntaxScopeOriginScopeIds: Set<ObjectIdentifier> = {
            var ids: Set<ObjectIdentifier> = []
            var current: (any SyntaxScopeProtocol)? =
                self.findStartingScopeForLookup(position: position)
            while let scope = current {
                ids.insert(ObjectIdentifier(scope))
                current = scope.lookupParent
            }
            return ids
        }()

        return LookupResultData(
            clientX: info.clientX,
            clientY: info.clientY,
            sourceLocationDescription: sourceLocationDescription,
            lexicalLookupNames: lexicalLookupNames,
            syntaxScopeNames: syntaxScopeNames,
            lexicalLookupOriginSyntaxIds: lexicalLookupOriginSyntaxIds,
            syntaxScopeOriginScopeIds: syntaxScopeOriginScopeIds
        )
    }
}

private extension String {
    // Parse the user-entered text as Swift source and pull out the first identifier-like
    // token. Empty / whitespace-only / non-identifier inputs return nil so lookup falls back
    // to "all names at this position".
    var asLookupIdentifier: Identifier? {
        guard !isEmpty else { return nil }
        let parsed = Parser.parse(source: self)
        return parsed.tokens(viewMode: .sourceAccurate)
            .first { $0.tokenKind != .endOfFile }
            .flatMap { Identifier($0) }
    }
}
