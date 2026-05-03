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
