import React
import SwiftSyntax
import SwiftParser
import SwiftSyntaxScope
@_spi(Experimental) import SwiftLexicalLookup
import SwiftCodeEditor

@propertyWrapper
internal struct LookupHook: Hook {
    internal init() {
        _result = State(wrappedValue: nil)
        _onLookup = Callback()
        _onLookupClose = Callback()
    }

    @State private var result: LookupResultData?
    @Callback var onLookup: Function<Void, ClickPointInfo>
    @Callback var onLookupClose: Function<Void>

    internal var wrappedValue: LookupResultData? { result }
    internal var projectedValue: Self { self }

    internal func callAsFunction(scope: SourceFileScope, config: LookupConfig) {
        $onLookup(deps: [scope.syntax.id, config]) { (info) in
            result = scope.makeLookupResult(info: info, config: config)
        }

        $onLookupClose(deps: []) {
            result = nil
        }
    }
}

internal struct LookupResultName: Hashable {
    var label: String
    var range: Range<AbsolutePosition>
    var rangeDescription: String
}

internal struct LookupResultData: Hashable {
    var anchorPoint: SIMD2<Double>
    var sourceLocationDescription: String
    var lexicalLookupNames: [LookupResultName]
    var syntaxScopeNames: [LookupResultName]
    var lexicalLookupOriginSyntaxIds: Set<SyntaxIdentifier>
    var syntaxScopeOriginScopeIds: Set<ObjectIdentifier>
}

extension SourceFileScope {
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
            anchorPoint: info.clientPoint,
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
