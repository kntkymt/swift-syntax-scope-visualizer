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
        _parsed = State(wrappedValue: Self.parse(text: ""))
        _parseEffect = Effect()
    }

    @State private var parsed: ParsedSource
    @Effect private var parseEffect

    internal var wrappedValue: ParsedSource { parsed }
    internal var projectedValue: Self { self }

    // Debounce text -> SourceFileSyntax. Cleanup captures `timer` so that
    // dropping the closure releases the JSTimer, triggering clearTimeout
    // via its deinit.
    internal func callAsFunction(text: String) {
        $parseEffect(deps: [text]) {
            let pendingText = text
            let timer = JSTimer(millisecondsDelay: 500) {
                self.parsed = Self.parse(text: pendingText)
            }

            return {
                _ = timer
            }
        }
    }

    static func parse(text: String) -> ParsedSource {
        let syntax = Parser.parse(source: text)
        let scope = SourceFileScope(syntax: syntax)
        scope.buildFullyExpandedTree()
        return ParsedSource(text: text, syntax: syntax, scope: scope)
    }
}

struct ParsedSource: Hashable {
    let text: String
    let syntax: SourceFileSyntax
    let scope: SourceFileScope

    init(text: String, syntax: SourceFileSyntax, scope: SourceFileScope) {
        self.text = text
        self.syntax = syntax
        self.scope = scope
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.text == b.text
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
    }
}
