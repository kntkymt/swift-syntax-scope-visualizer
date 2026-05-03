internal struct LookupConfig: Hashable {
    static var `default`: LookupConfig {
        LookupConfig(
            name: "",
            swiftLexicalLookup: .default,
            swiftSyntaxScope: .default
        )
    }

    var name: String
    var swiftLexicalLookup: SwiftLexicalLookup
    var swiftSyntaxScope: SwiftSyntaxScope

    struct SwiftLexicalLookup: Hashable {
        static var `default`: SwiftLexicalLookup {
            SwiftLexicalLookup(finishInSequentialScope: false)
        }

        var finishInSequentialScope: Bool
    }

    struct SwiftSyntaxScope: Hashable {
        static var `default`: SwiftSyntaxScope {
            SwiftSyntaxScope(includeOuterResults: true)
        }

        var includeOuterResults: Bool
    }
}
