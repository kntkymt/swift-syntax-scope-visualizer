internal struct TreeNodeHighlights<ID: Hashable>: Hashable {
    internal struct Entry: Hashable {
        var ids: Set<ID>
        var color: String
    }

    var entries: [Entry]

    init(_ entries: [Entry]) {
        self.entries = entries
    }

    // First matching entry wins, so callers list higher-priority colors first.
    func color(for id: ID) -> String? {
        entries.first { $0.ids.contains(id) }?.color
    }
}
