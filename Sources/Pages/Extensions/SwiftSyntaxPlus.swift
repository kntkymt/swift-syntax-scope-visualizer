import SwiftSyntax

internal extension Range<AbsolutePosition> {
    func description(converter: SourceLocationConverter) -> String {
        let lower = converter.location(for: lowerBound)
        let upper = converter.location(for: upperBound)
        return "[\(lower.line):\(lower.column) - \(upper.line):\(upper.column)]"
    }
}

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
