extension SwiftLexicalLookupPane {
    internal struct VisibleNodeConfig: Hashable {
        static var `default`: VisibleNodeConfig {
            VisibleNodeConfig(
                hideEmptyCollections: true,
                hideTokens: true,
                hideNonScope: false
            )
        }

        var hideEmptyCollections: Bool
        var hideTokens: Bool
        var hideNonScope: Bool
    }
}
