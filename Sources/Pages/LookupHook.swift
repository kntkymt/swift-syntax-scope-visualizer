import React
import SwiftCodeEditor
import SwiftSyntax
import SwiftSyntaxScope

@propertyWrapper
internal struct LookupHook: Hook {
    internal init() {
        _result = State(wrappedValue: nil)
        _onLookup = Callback()
        _onLookupClose = Callback()
    }

    @State private var result: LookupResultData?
    @Callback var onLookup: Function<Void, ClickPointInfo>
    @Callback var onLookupClose: Function<Void>

    internal var wrappedValue: LookupResultData? { result }
    internal var projectedValue: Self { self }

    internal func callAsFunction(scope: SourceFileScope, config: LookupConfig) {
        $onLookup(deps: [scope.syntax.id, config]) { (info) in
            result = scope.makeLookupResult(info: info, config: config)
        }

        $onLookupClose(deps: []) {
            result = nil
        }
    }
}
