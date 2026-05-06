import React
import SwiftParser
import SwiftSyntax
import SwiftSyntaxScope
@_spi(Experimental) import SwiftLexicalLookup
import SRTJavaScriptKitEx

@propertyWrapper
internal struct ParseSourceHook: Hook {
    internal init() {
        _parsed = State()
        _parseEffect = Effect()
    }

    @State private var parsed: ParsedSource?
    @Effect private var parseEffect

    internal var wrappedValue: ParsedSource? { parsed }
    internal var projectedValue: Self { self }

    // Debounce text -> SourceFileSyntax. Cleanup captures `timer` so that
    // dropping the closure releases the JSTimer, triggering clearTimeout
    // via its deinit.
    internal func callAsFunction(sourceCode: String) {
        $parseEffect(deps: [sourceCode]) {
            let pendingSourceCode = sourceCode
            let timer = JSTimer(millisecondsDelay: 500) {
                self.parsed = Self.parse(sourceCode: pendingSourceCode)
            }

            return {
                _ = timer
            }
        }
    }

    static func parse(sourceCode: String) -> ParsedSource {
        let syntax = Parser.parse(source: sourceCode)
        let scope = SourceFileScope(syntax: syntax)
        scope.buildFullyExpandedTree()
        return ParsedSource(sourceCode: sourceCode, syntax: syntax, scope: scope)
    }
}

struct ParsedSource: Hashable {
    let sourceCode: String
    let syntax: SourceFileSyntax
    let scope: SourceFileScope
    let converter: SourceLocationConverter

    init(sourceCode: String, syntax: SourceFileSyntax, scope: SourceFileScope) {
        self.sourceCode = sourceCode
        self.syntax = syntax
        self.scope = scope
        self.converter = SourceLocationConverter(fileName: "", tree: syntax.root)
    }
}
