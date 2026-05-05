import React
import SwiftParser
import SwiftSyntax
import SwiftSyntaxScope
@_spi(Experimental) import SwiftLexicalLookup
import SRTJavaScriptKitEx

@propertyWrapper
internal struct ParseSourceHook: Hook {
    internal init() {
        // TODO: Optionalで管理
        _parsed = State(wrappedValue: Self.parse(sourceCode: ""))
        _parseEffect = Effect()
    }

    @State private var parsed: ParsedSource
    @Effect private var parseEffect

    internal var wrappedValue: ParsedSource { parsed }
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

    init(sourceCode: String, syntax: SourceFileSyntax, scope: SourceFileScope) {
        self.sourceCode = sourceCode
        self.syntax = syntax
        self.scope = scope
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.sourceCode == b.sourceCode
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(sourceCode)
    }
}
