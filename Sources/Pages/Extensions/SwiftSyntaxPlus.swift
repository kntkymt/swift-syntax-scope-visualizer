import SwiftSyntax

internal extension SyntaxProtocol {
    var declNames: [String] {
        if let extensionDecl = self.as(ExtensionDeclSyntax.self),
            let identifierType = extensionDecl.extendedType.as(IdentifierTypeSyntax.self)
        {
            return [identifierType.name.text]
        }

        return Syntax(self).introducedNameTexts
    }
}

extension SourceRange {
    var description: String {
        // SourceRange uses half-open (..<) semantics; render the upper bound
        // inclusively for display.
        let displayedEndColumn = start == end ? end.column : end.column - 1
        return "[\(start.line):\(start.column) - \(end.line):\(displayedEndColumn)]"
    }
}

// SourceLocationConverter is a reference type without Hashable conformance.
// We treat identity equality as value equality so a converter shared via
// ParsedSource can participate in Hashable-derived deps.
extension SourceLocationConverter: @retroactive Equatable, @retroactive Hashable {
    public static func == (lhs: SourceLocationConverter, rhs: SourceLocationConverter) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
