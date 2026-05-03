internal struct LexicalLookupConfig: Hashable {
    static var `default`: LexicalLookupConfig {
        LexicalLookupConfig(
            hideEmptyCollections: true,
            hideTokens: true,
            hideNonScope: false
        )
    }

    var hideEmptyCollections: Bool
    var hideTokens: Bool
    var hideNonScope: Bool
}
