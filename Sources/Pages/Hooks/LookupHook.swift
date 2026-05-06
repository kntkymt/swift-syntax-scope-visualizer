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

    internal func callAsFunction(scope: SourceFileScope?, config: LookupConfig) {
        $onLookup(deps: [scope?.syntax.id, config]) { (info) in
            guard let scope else { return }
            result = scope.makeLookupResult(info: info, config: config)
        }

        $onLookupClose(deps: []) {
            result = nil
        }
    }
}

internal struct LookupResultData: Hashable {
    var anchorPoint: SIMD2<Double>
    var sourceLocationDescription: String
    var lexicalLookupResults: [LookupResultDisplay<SyntaxIdentifier>]
    var syntaxScopeResults: [LookupResultDisplay<ObjectIdentifier>]
    var lexicalLookupOriginSyntaxIds: Set<SyntaxIdentifier>
    var syntaxScopeOriginScopeIds: Set<ObjectIdentifier>
}

internal struct LookupResultDisplay<NodeID: Hashable>: Hashable {
    var headerLabel: String
    var headerNodeId: NodeID
    var headerRange: Range<AbsolutePosition>
    var headerRangeDescription: String
    var names: [LookupNameDisplay<NodeID>]
}

internal indirect enum LookupNameDisplay<NodeID: Hashable>: Hashable {
    case leaf(
        label: String,
        nodeId: NodeID,
        range: Range<AbsolutePosition>,
        rangeDescription: String,
        accessibleAfterDescription: String?
    )
    case equivalentNames([LookupNameDisplay<NodeID>])
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

        let lexicalLookupResults =
            (originToken?.lookup(identifier, with: lexicalConfig) ?? [])
            .map { $0.toDisplay(converter: converter) }

        let syntaxScopeResults = self.lexicalLookup(
            position: position,
            name: identifier,
            options: options
        )
        .map { $0.toDisplay(converter: converter) }

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
                ids.insert(scope.id)
                current = scope.lookupParent
            }
            return ids
        }()

        return LookupResultData(
            anchorPoint: info.clientPoint,
            sourceLocationDescription: sourceLocationDescription,
            lexicalLookupResults: lexicalLookupResults,
            syntaxScopeResults: syntaxScopeResults,
            lexicalLookupOriginSyntaxIds: lexicalLookupOriginSyntaxIds,
            syntaxScopeOriginScopeIds: syntaxScopeOriginScopeIds
        )
    }
}

private extension SwiftLexicalLookup.LookupResult {
    func toDisplay(converter: SourceLocationConverter) -> LookupResultDisplay<SyntaxIdentifier> {
        let resultKindLabel: String
        let headerSyntax: SyntaxProtocol
        let typeLabel: String
        let names: [SwiftLexicalLookup.LookupName]
        switch self {
        case .fromScope(let syntax, let withNames):
            resultKindLabel = "fromScope"
            headerSyntax = syntax
            typeLabel =
                (syntax.asProtocol(SyntaxProtocol.self) as? ScopeSyntax)?.scopeDebugName
                ?? "\(syntax.syntaxNodeType)"
            names = withNames
        case .lookForMembers(let syntax):
            resultKindLabel = "lookForMembers"
            headerSyntax = syntax
            typeLabel = "\(syntax.syntaxNodeType)"
            names = []
        case .lookForGenericParameters(let extensionDecl):
            resultKindLabel = "lookForGenericParameters"
            headerSyntax = extensionDecl
            typeLabel = "\(extensionDecl.syntaxNodeType)"
            names = []
        case .lookForImplicitClosureParameters(let closureExpr):
            resultKindLabel = "lookForImplicitClosureParameters"
            headerSyntax = closureExpr
            typeLabel = "\(closureExpr.syntaxNodeType)"
            names = []
        }

        return LookupResultDisplay(
            headerLabel: "\(resultKindLabel):\(typeLabel)",
            headerNodeId: headerSyntax.id,
            headerRange: headerSyntax.trimmedRange,
            headerRangeDescription: headerSyntax.sourceRange(converter: converter).description,
            names: names.map { $0.toDisplay(converter: converter) }
        )
    }
}

private extension SwiftLexicalLookup.LookupName {
    func toDisplay(converter: SourceLocationConverter) -> LookupNameDisplay<SyntaxIdentifier> {
        switch self {
        case .equivalentNames(let names):
            return .equivalentNames(names.map { $0.toDisplay(converter: converter) })
        case .identifier(let syntax, let accessibleAfter):
            let accessibleAfterDescription: String? = accessibleAfter.map { position in
                let location = converter.location(for: position)
                return "[\(location.line):\(location.column)]"
            }
            return .leaf(
                label: displayDescription,
                nodeId: syntax.id,
                range: syntax.trimmedRange,
                rangeDescription: syntax.sourceRange(converter: converter).description,
                accessibleAfterDescription: accessibleAfterDescription
            )
        case .declaration(let syntax):
            return .leaf(
                label: displayDescription,
                nodeId: syntax.id,
                range: syntax.trimmedRange,
                rangeDescription: syntax.sourceRange(converter: converter).description,
                accessibleAfterDescription: nil
            )
        case .implicit(let decl):
            return .leaf(
                label: displayDescription,
                nodeId: decl.syntax.id,
                range: decl.syntax.trimmedRange,
                rangeDescription: decl.syntax.sourceRange(converter: converter).description,
                accessibleAfterDescription: nil
            )
        }
    }
}

private extension SwiftSyntaxScope.LookupResult {
    func toDisplay(converter: SourceLocationConverter) -> LookupResultDisplay<ObjectIdentifier> {
        let resultKindLabel: String
        switch self {
        case .fromScope:
            resultKindLabel = "fromScope"
        case .fromMembers:
            resultKindLabel = "fromMembers"
        }
        let scopeId = scope.id

        return LookupResultDisplay(
            headerLabel: "\(resultKindLabel):\(scope.scopeTypeDescription)",
            headerNodeId: scopeId,
            headerRange: scope.range,
            headerRangeDescription: scope.sourceRange(converter: converter).description,
            names: names.map { $0.toDisplay(scopeId: scopeId, converter: converter) }
        )
    }
}

private extension SwiftSyntaxScope.LookupName {
    // A SyntaxScope name lives inside its origin scope, so reuse the enclosing
    // scope's id as the highlight target — hovering the name lights up the same
    // scope-tree node as the result header.
    func toDisplay(
        scopeId: ObjectIdentifier,
        converter: SourceLocationConverter
    ) -> LookupNameDisplay<ObjectIdentifier> {
        .leaf(
            label: "\(kind):\(text)",
            nodeId: scopeId,
            range: syntax.trimmedRange,
            rangeDescription: syntax.sourceRange(converter: converter).description,
            accessibleAfterDescription: nil
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
