import SwiftSyntax

internal extension Range<AbsolutePosition> {
    func description(converter: SourceLocationConverter) -> String {
        let lower = converter.location(for: lowerBound)
        let upper = converter.location(for: upperBound)
        return "[\(lower.line):\(lower.column) - \(upper.line):\(upper.column)]"
    }
}
